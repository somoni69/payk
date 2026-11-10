import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  return ref.watch(loyaltyApiProvider).sizeOffers();
});

final messagesProvider = FutureProvider<List<LoyaltyMessageItem>>((ref) async {
  final token = ref.watch(sessionProvider.select((session) => session.accessToken));
  if (token == null || token.isEmpty) return const [];
  return ref.watch(loyaltyApiProvider).messages();
});
