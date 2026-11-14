import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/size_offers_logic.dart';
import 'api/api_exception.dart';
import 'models/models.dart';
import 'session/session_controller.dart';

export 'session/session_controller.dart';

final programProvider = FutureProvider<ProgramInfo>((ref) {
  return ref.watch(loyaltyApiProvider).program();
});

final rulesProvider = FutureProvider<RulesInfo>((ref) {
  return ref.watch(loyaltyApiProvider).rules();
});

final meProvider = FutureProvider<Account>((ref) async {
  final token = ref.watch(sessionProvider.select((session) => session.accessToken));
  if (token == null || token.isEmpty) {
    throw ApiException(401, 'Войдите снова');
  }
  return ref.watch(loyaltyApiProvider).me();
});

final historyProvider = FutureProvider<List<HistoryEntry>>((ref) async {
  final token = ref.watch(sessionProvider.select((session) => session.accessToken));
  if (token == null || token.isEmpty) return const [];
  return ref.watch(loyaltyApiProvider).history();
});

final friendsProvider = FutureProvider<FriendsInfo>((ref) async {
  final token = ref.watch(sessionProvider.select((session) => session.accessToken));
  if (token == null || token.isEmpty) {
    throw ApiException(401, 'Войдите снова');
  }
  return ref.watch(loyaltyApiProvider).friends();
});

final sizeOffersProvider = FutureProvider<List<SizeOffer>>((ref) async {
  final token = ref.watch(sessionProvider.select((session) => session.accessToken));
  if (token == null || token.isEmpty) return const [];
  final res = await ref.watch(loyaltyApiProvider).sizeOffers(markRead: true);
  return res.items;
});

final sizeOffersPreviewProvider = FutureProvider<SizeOffersResponse>(
  (ref) async {
    final token = ref.watch(sessionProvider.select((session) => session.accessToken));
    if (token == null || token.isEmpty) {
      return SizeOffersResponse(items: const [], serverNow: DateTime.now());
    }
    try {
      return await ref.watch(loyaltyApiProvider).sizeOffers(markRead: false);
    } catch (_) {
      return SizeOffersResponse(items: const [], serverNow: DateTime.now());
    }
  },
  retry: (_, _) => null,
);

sealed class OfferClaimOutcome {
  const OfferClaimOutcome();
}

class OfferClaimSuccess extends OfferClaimOutcome {
  const OfferClaimSuccess(this.offer);
  final SizeOffer offer;
}

class OfferClaimConflict extends OfferClaimOutcome {
  const OfferClaimConflict({required this.status, required this.message});
  final String status;
  final String? message;
}

class OfferClaimRemoved extends OfferClaimOutcome {
  const OfferClaimRemoved(this.message);
  final String? message;
}

class SizeOffersFeedNotifier extends AsyncNotifier<SizeOffersResponse> {
  int _reqSeq = 0;

  @override
  Future<SizeOffersResponse> build() async {
    final token = ref.watch(sessionProvider.select((session) => session.accessToken));
    if (token == null || token.isEmpty) {
      return SizeOffersResponse(items: const [], serverNow: DateTime.now());
    }
    final seq = ++_reqSeq;
    final fresh = await ref.watch(loyaltyApiProvider).sizeOffers(markRead: true);
    if (!ref.mounted || seq != _reqSeq) {
      return state.asData?.value ?? fresh;
    }
    return fresh;
  }

  Future<void> reload() async {
    final token = ref.read(sessionProvider).accessToken;
    if (token == null || token.isEmpty) return;
    final seq = ++_reqSeq;
    final prev = state.asData?.value;
    if (prev == null) {
      state = const AsyncLoading();
    }
    try {
      final fresh = await ref.read(loyaltyApiProvider).sizeOffers(markRead: true);
      if (!ref.mounted || seq != _reqSeq) return;
      final merged = mergeSizeOffers(prev?.items, fresh.items);
      state = AsyncData(SizeOffersResponse(items: merged, serverNow: fresh.serverNow));
    } catch (error, stackTrace) {
      if (!ref.mounted || seq != _reqSeq) return;
      if (prev == null) {
        state = AsyncError(error, stackTrace);
      }
    }
  }

  Future<OfferClaimOutcome> claim(SizeOffer offer, {required DateTime serverClock}) async {
    try {
      final updated = await ref.read(loyaltyApiProvider).claimSizeOffer(offer.id);
      _reqSeq++;
      final current = state.asData?.value;
      if (current != null && ref.mounted) {
        final nextItems = [
          for (final item in current.items)
            if (item.id == offer.id)
              item.copyWith(
                claimed: true,
                promoCode: updated.promoCode ?? item.promoCode,
                status: 'ACTIVE',
                issued: updated.issued,
              )
            else
              item,
        ];
        state = AsyncData(SizeOffersResponse(items: nextItems, serverNow: current.serverNow));
        ref.invalidate(sizeOffersPreviewProvider);
        ref.invalidate(sizeOffersProvider);
      }
      return OfferClaimSuccess(updated);
    } on ApiException catch (error) {
      if (error.status == 409) {
        final nextStatus = statusAfterOfferConflict(
          offer,
          serverClock,
          detail: error.message,
        );
        _reqSeq++;
        final current = state.asData?.value;
        if (current != null && ref.mounted) {
          final nextItems = [
            for (final item in current.items)
              if (item.id == offer.id) item.copyWith(status: nextStatus) else item,
          ];
          state = AsyncData(SizeOffersResponse(items: nextItems, serverNow: current.serverNow));
          ref.invalidate(sizeOffersPreviewProvider);
        }
        return OfferClaimConflict(status: nextStatus, message: error.message);
      }
      if (error.status == 404) {
        _reqSeq++;
        final current = state.asData?.value;
        if (current != null && ref.mounted) {
          final nextItems = current.items.where((item) => item.id != offer.id).toList();
          state = AsyncData(SizeOffersResponse(items: nextItems, serverNow: current.serverNow));
          ref.invalidate(sizeOffersPreviewProvider);
        }
        return OfferClaimRemoved(error.message);
      }
      rethrow;
    }
  }
}

final sizeOffersFeedProvider =
    AsyncNotifierProvider<SizeOffersFeedNotifier, SizeOffersResponse>(
  SizeOffersFeedNotifier.new,
);

const Duration _receiptsFilterTtl = Duration(minutes: 30);

class ReceiptsFilterCache {
  const ReceiptsFilterCache({
    this.memberId,
    this.query = const ReceiptsQuery(),
    required this.savedAt,
  });

  final int? memberId;
  final ReceiptsQuery query;
  final DateTime savedAt;
}

class ReceiptsFilterNotifier extends Notifier<ReceiptsFilterCache> {
  @override
  ReceiptsFilterCache build() {
    ref.watch(sessionProvider.select((s) => s.accessToken));
    return ReceiptsFilterCache(savedAt: DateTime.now());
  }

  ReceiptsQuery readFor(int? memberId) {
    final now = DateTime.now();
    if (state.memberId != memberId) return const ReceiptsQuery();
    if (now.difference(state.savedAt) > _receiptsFilterTtl) {
      return const ReceiptsQuery();
    }
    return state.query;
  }

  void writeFor(int? memberId, ReceiptsQuery query) {
    state = ReceiptsFilterCache(
      memberId: memberId,
      query: query,
      savedAt: DateTime.now(),
    );
  }
}

final receiptsFilterProvider =
    NotifierProvider<ReceiptsFilterNotifier, ReceiptsFilterCache>(
  ReceiptsFilterNotifier.new,
);

final receiptDetailProvider = FutureProvider.family<ReceiptView, int>((ref, id) async {
  final token = ref.watch(sessionProvider.select((session) => session.accessToken));
  if (token == null || token.isEmpty) {
    throw ApiException(401, 'Войдите снова');
  }
  return ref.watch(loyaltyApiProvider).receipt(id);
});

final messagesProvider = FutureProvider<List<LoyaltyMessageItem>>((ref) async {
  final token = ref.watch(sessionProvider.select((session) => session.accessToken));
  if (token == null || token.isEmpty) return const [];
  return ref.watch(loyaltyApiProvider).messages();
});
