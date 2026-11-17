import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/states.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'receipt_detail_screen.dart';

/// Вкладка «Чеки» внутри экрана истории: шапка месяца, фильтры, группировка по месяцам.
class ReceiptsTab extends ConsumerStatefulWidget {
  const ReceiptsTab({super.key});

  @override
  ConsumerState<ReceiptsTab> createState() => _ReceiptsTabState();
}

class _ReceiptsTabState extends ConsumerState<ReceiptsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  ReceiptsQuery _query = const ReceiptsQuery();
  bool _filtersOpen = false;
  bool _initDone = false;

  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  ReceiptsPage? _page;
  final List<ReceiptRow> _items = <ReceiptRow>[];
  int? _nextBeforeId;
  int _reqSeq = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final memberId = ref.read(meProvider).asData?.value.member.id;
      final cached = ref.read(receiptsFilterProvider.notifier).readFor(memberId);
      _query = cached;
      if (cached.search.isNotEmpty) {
        _searchCtrl.text = cached.search;
      }
      _filtersOpen = cached.filterCount > 0;
      _initDone = true;
      _fetch(reset: true);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!_initDone) return;
    final nextText = _searchCtrl.text;
    if (nextText == _query.search) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _applyQuery(_query.copyWith(search: nextText));
    });
  }

  void _applyQuery(ReceiptsQuery next) {
    final memberId = ref.read(meProvider).asData?.value.member.id;
    ref.read(receiptsFilterProvider.notifier).writeFor(memberId, next);
    setState(() => _query = next);
    _fetch(reset: true);
  }

  Future<void> _fetch({required bool reset}) async {
    final seq = ++_reqSeq;
    setState(() {
      if (reset) {
        _loading = _items.isEmpty;
        _error = null;
      } else {
        _loadingMore = true;
      }
    });

    try {
      final res = await ref.read(loyaltyApiProvider).receipts(
            beforeId: reset ? null : _nextBeforeId,
            dFrom: _query.dFrom.isEmpty ? null : _query.dFrom,
            dTo: _query.dTo.isEmpty ? null : _query.dTo,
            fmt: _query.fmt.isEmpty ? null : _query.fmt,
            q: _query.search.trim().isEmpty ? null : _query.search.trim(),
          );
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        if (reset) {
          _page = res;
          _items
            ..clear()
            ..addAll(res.items);
        } else {
          final seen = {for (final item in _items) item.id};
          for (final item in res.items) {
            if (seen.add(item.id)) _items.add(item);
          }
        }
        _nextBeforeId = res.nextBeforeId;
        _loading = false;
        _loadingMore = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _error = error;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initialRaw = isFrom ? _query.dFrom : _query.dTo;
    final initial = DateTime.tryParse(initialRaw) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    final iso = formatIsoDate(picked);
    _applyQuery(
      isFrom ? _query.copyWith(dFrom: iso) : _query.copyWith(dTo: iso),
    );
  }

  void _openDetail(ReceiptRow row) {
    HapticFeedback.lightImpact();
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push('/history/receipt/${row.id}');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReceiptDetailScreen(receiptId: row.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final header = _page?.header;
    final monthsByKey = {
      for (final m in _page?.months ?? const <ReceiptMonth>[]) m.month: m,
    };

    return RefreshIndicator(
      color: PaykColors.violet,
      backgroundColor: Colors.white,
      onRefresh: () => _fetch(reset: true),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          28 + MediaQuery.paddingOf(context).bottom,
        ),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          if (header != null) ...[
            _ReceiptsHeaderCard(header: header, locale: locale),
            const SizedBox(height: 12),
          ],
          _FilterBar(
            controller: _searchCtrl,
            query: _query,
            locale: locale,
            filtersOpen: _filtersOpen,
            onToggleFilters: () => setState(() => _filtersOpen = !_filtersOpen),
            onClearSearch: () {
              _searchCtrl.clear();
              _applyQuery(_query.copyWith(search: ''));
            },
            onPickFrom: () => _pickDate(isFrom: true),
            onPickTo: () => _pickDate(isFrom: false),
            onClearDates: () => _applyQuery(_query.copyWith(dFrom: '', dTo: '')),
            onSelectFmt: (fmt) => _applyQuery(_query.copyWith(fmt: fmt)),
            onReset: () {
              _searchCtrl.clear();
              _applyQuery(const ReceiptsQuery());
            },
          ),
          const SizedBox(height: 12),
          if (_loading && _items.isEmpty)
            const _ReceiptsLoadingSkeleton()
          else if (_error != null && _items.isEmpty)
            ErrorState(
              message: _error is ApiException
                  ? (_error as ApiException).message
                  : tr(locale, 'receipts.loadError'),
              onRetry: () => _fetch(reset: true),
            )
          else if (_items.isEmpty)
            _EmptyReceiptsCard(
              filtered: _query.isFiltered,
              locale: locale,
              onReset: _query.isFiltered
                  ? () {
                      _searchCtrl.clear();
                      _applyQuery(const ReceiptsQuery());
                    }
                  : null,
            )
          else ...[
            ..._buildGroupedRows(locale, monthsByKey),
            if (_nextBeforeId != null) ...[
              const SizedBox(height: 14),
              Center(
                child: OutlinedButton(
                  onPressed: _loadingMore ? null : () => _fetch(reset: false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: PaykColors.primary,
                    side: const BorderSide(color: PaykColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _loadingMore
                        ? tr(locale, 'history.loading')
                        : tr(locale, 'history.more'),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  List<Widget> _buildGroupedRows(
    String locale,
    Map<String, ReceiptMonth> monthsByKey,
  ) {
    final widgets = <Widget>[];
    String? currentMonth;
    for (final row in _items) {
      final mKey = monthKeyOf(row.ts);
      if (mKey != currentMonth) {
        currentMonth = mKey;
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 14));
        widgets.add(
          _MonthHeaderRow(
            monthKey: mKey,
            stats: monthsByKey[mKey],
            locale: locale,
          ),
        );
        widgets.add(const SizedBox(height: 8));
      } else {
        widgets.add(const SizedBox(height: 8));
      }
      widgets.add(
        _ReceiptRowCard(
          row: row,
          locale: locale,
          onTap: () => _openDetail(row),
        ),
      );
    }
    return widgets;
  }
}

class _ReceiptsHeaderCard extends StatelessWidget {
  const _ReceiptsHeaderCard({required this.header, required this.locale});

  final ReceiptsHeader header;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaykColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatMonthTitle(header.month, locale),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: PaykColors.textPrimary,
                  ),
                ),
              ),
              Text(
                receiptsCountLabel(locale, header.bills),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: PaykColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _HeaderStat(
                  label: tr(locale, 'receipts.head.spend'),
                  value: formatMoney(header.spendMonth),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HeaderStat(
                  label: tr(locale, 'receipts.head.earned'),
                  value: '+${formatMoney(header.earned)}',
                  color: PaykColors.success,
                ),
              ),
            ],
          ),
          if (header.spent > 0 || header.toNext != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (header.spent > 0)
                  Expanded(
                    child: _HeaderStat(
                      label: tr(locale, 'receipts.head.spent'),
                      value: '−${formatMoney(header.spent)}',
                    ),
                  ),
                if (header.spent > 0 && (header.toNext != null || header.spendMonth > 0))
                  const SizedBox(width: 10),
                Expanded(
                  child: header.toNext != null
                      ? _HeaderStat(
                          label: tr(locale, 'receipts.head.toNext'),
                          value: formatMoney(header.toNext!),
                          color: PaykColors.primary,
                        )
                      : _HeaderStat(
                          label: tr(locale, 'receipts.head.top'),
                          value: '✓',
                          color: PaykColors.primary,
                        ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.label,
    required this.value,
    this.color = PaykColors.textPrimary,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: PaykColors.tile,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: PaykColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.query,
    required this.locale,
    required this.filtersOpen,
    required this.onToggleFilters,
    required this.onClearSearch,
    required this.onPickFrom,
    required this.onPickTo,
    required this.onClearDates,
    required this.onSelectFmt,
    required this.onReset,
  });

  final TextEditingController controller;
  final ReceiptsQuery query;
  final String locale;
  final bool filtersOpen;
  final VoidCallback onToggleFilters;
  final VoidCallback onClearSearch;
  final VoidCallback onPickFrom;
  final VoidCallback onPickTo;
  final VoidCallback onClearDates;
  final ValueChanged<String> onSelectFmt;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final activeCount = query.filterCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: PaykColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: PaykColors.textSecondary,
                      size: 20,
                    ),
                    suffixIcon: query.search.isNotEmpty
                        ? IconButton(
                            onPressed: onClearSearch,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: PaykColors.textMuted,
                            ),
                          )
                        : null,
                    hintText: tr(locale, 'receipts.search'),
                    hintStyle: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: PaykColors.textSecondary,
                    ),
                    filled: true,
                    fillColor: PaykColors.sheet,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: PaykColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: PaykColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: PaykColors.primary,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 0,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            PaykPressable(
              scaleDown: PaykMotion.scaleIcon,
              onTap: onToggleFilters,
              child: AnimatedContainer(
                duration: PaykMotion.duration(context, PaykMotion.fast),
                curve: PaykMotion.easeOut,
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: (filtersOpen || activeCount > 0)
                      ? PaykColors.activePill
                      : PaykColors.sheet,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: (filtersOpen || activeCount > 0)
                        ? PaykColors.primary.withValues(alpha: 0.35)
                        : PaykColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 19,
                      color: (filtersOpen || activeCount > 0)
                          ? PaykColors.primary
                          : PaykColors.textSecondary,
                    ),
                    if (activeCount > 0) ...[
                      const SizedBox(width: 4),
                      Text(
                        '$activeCount',
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: PaykColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: PaykMotion.duration(context, PaykMotion.normal),
          curve: PaykMotion.easeOut,
          alignment: Alignment.topCenter,
          child: filtersOpen
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: PaykColors.sheet,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PaykColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _DateButton(
                                label: tr(locale, 'receipts.from'),
                                value: query.dFrom,
                                onTap: onPickFrom,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _DateButton(
                                label: tr(locale, 'receipts.to'),
                                value: query.dTo,
                                onTap: onPickTo,
                              ),
                            ),
                            if (query.dFrom.isNotEmpty || query.dTo.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: onClearDates,
                                icon: const Icon(Icons.close_rounded, size: 18),
                                color: PaykColors.textMuted,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tr(locale, 'receipts.fmt'),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: PaykColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _FormatTile(
                                label: tr(locale, 'receipts.fmtAll'),
                                assetPath: 'assets/3d/receipt.webp',
                                selected: query.fmt.isEmpty,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  onSelectFmt('');
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _FormatTile(
                                label: tr(locale, 'format.SM'),
                                assetPath: 'assets/3d/cart.webp',
                                selected: query.fmt == 'SM',
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  onSelectFmt('SM');
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _FormatTile(
                                label: tr(locale, 'format.CL'),
                                assetPath: 'assets/3d/coat.webp',
                                selected: query.fmt == 'CL',
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  onSelectFmt('CL');
                                },
                              ),
                            ),
                          ],
                        ),
                        if (query.isFiltered) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: onReset,
                              child: Text(
                                tr(locale, 'receipts.reset'),
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontWeight: FontWeight.w700,
                                  color: PaykColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PaykPressable(
      scaleDown: PaykMotion.scaleButton,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: PaykColors.tile,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PaykColors.border),
        ),
        child: Row(
          children: [
            Text(
              '$label: ',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: PaykColors.textSecondary,
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '—' : value,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PaykColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptsLoadingSkeleton extends StatelessWidget {
  const _ReceiptsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            const SkeletonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: SkeletonBox(height: 16, width: 140, radius: 6)),
                      SizedBox(width: 16),
                      SkeletonBox(height: 16, width: 72, radius: 6),
                    ],
                  ),
                  SizedBox(height: 8),
                  SkeletonBox(height: 12, width: 180, radius: 6),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  const _FormatTile({
    required this.label,
    required this.assetPath,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String assetPath;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dur = PaykMotion.duration(context, PaykMotion.fast);
    return PaykPressable(
      scaleDown: PaykMotion.scaleButton,
      onTap: onTap,
      child: AnimatedContainer(
        duration: dur,
        curve: PaykMotion.easeOut,
        height: 64,
        decoration: BoxDecoration(
          color: selected ? PaykColors.activePill : PaykColors.surfaceNested,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? PaykColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 9, 28, 6),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: selected ? PaykColors.primary : PaykColors.textPrimary,
                ),
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: AnimatedScale(
                scale: selected ? 1.08 : 1.0,
                duration: dur,
                curve: PaykMotion.easeOut,
                child: Image.asset(
                  assetPath,
                  width: 34,
                  height: 34,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyReceiptsCard extends StatelessWidget {
  const _EmptyReceiptsCard({
    required this.filtered,
    required this.locale,
    this.onReset,
  });

  final bool filtered;
  final String locale;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaykColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: PaykColors.activePill,
            ),
            child: Center(
              child: Image.asset(
                'assets/3d/receipt.webp',
                width: 44,
                height: 44,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr(locale, filtered ? 'receipts.notFound' : 'receipts.empty'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: PaykColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr(locale, filtered ? 'receipts.notFoundText' : 'receipts.emptyText'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color: PaykColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (onReset != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onReset,
              style: OutlinedButton.styleFrom(
                foregroundColor: PaykColors.primary,
                side: const BorderSide(color: PaykColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(tr(locale, 'receipts.reset')),
            ),
          ],
        ],
      ),
    );
  }
}

class _MonthHeaderRow extends StatelessWidget {
  const _MonthHeaderRow({
    required this.monthKey,
    required this.stats,
    required this.locale,
  });

  final String monthKey;
  final ReceiptMonth? stats;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final s = stats;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatMonthTitle(monthKey, locale),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: PaykColors.textPrimary,
                  ),
                ),
              ),
              if (s != null)
                Text(
                  '${receiptsCountLabel(locale, s.bills)} · ${formatMoney(s.amount)}',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: PaykColors.textSecondary,
                  ),
                ),
            ],
          ),
          if (s != null && (s.earned > 0 || s.spent > 0)) ...[
            const SizedBox(height: 2),
            Wrap(
              spacing: 10,
              children: [
                if (s.earned > 0)
                  Text(
                    tr(locale, 'receipts.month.earned', {
                      'amount': '+${formatMoney(s.earned)}',
                    }),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PaykColors.success,
                    ),
                  ),
                if (s.spent > 0)
                  Text(
                    tr(locale, 'receipts.month.spent', {
                      'amount': formatMoney(s.spent),
                    }),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PaykColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ReceiptRowCard extends StatelessWidget {
  const _ReceiptRowCard({
    required this.row,
    required this.locale,
    required this.onTap,
  });

  final ReceiptRow row;
  final String locale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final store = (row.store != null && row.store!.trim().isNotEmpty)
        ? row.store!.trim()
        : tr(locale, 'receipts.titleShort');
    final fmt = row.format;
    final fmtLabel = fmt == 'SM' || fmt == 'CL'
        ? tr(locale, 'format.short.$fmt')
        : null;

    return PaykPressable(
      scaleDown: PaykMotion.scaleSubtle,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PaykColors.sheet,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: PaykColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          store,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: PaykColors.textPrimary,
                          ),
                        ),
                      ),
                      if (fmtLabel != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: PaykColors.activePill,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            fmtLabel,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: PaykColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatMoney(row.amount),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: PaykColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      if (row.number.isNotEmpty) '№ ${row.number}',
                      '${formatShortDate(row.ts)} ${formatTime(row.ts)}',
                    ].join(' · '),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: PaykColors.textSecondary,
                    ),
                  ),
                ),
                if (row.isReturned || row.isPartiallyReturned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: PaykColors.danger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tr(
                        locale,
                        row.isReturned
                            ? 'receipts.row.returned'
                            : 'receipts.row.partial',
                      ),
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: PaykColors.danger,
                      ),
                    ),
                  ),
              ],
            ),
            if (row.earn > 0 || row.burn > 0 || row.round > 0 || row.coupon > 0) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (row.earn > 0)
                    _RowChip(
                      text: tr(locale, 'receipts.row.earn', {
                        'amount': '+${formatMoney(row.earn)}',
                      }),
                      color: PaykColors.success,
                    ),
                  if (row.burn > 0)
                    _RowChip(
                      text: tr(locale, 'receipts.row.burn', {
                        'amount': '−${formatMoney(row.burn)}',
                      }),
                      color: PaykColors.textSecondary,
                    ),
                  if (row.round > 0)
                    _RowChip(
                      text: tr(locale, 'receipts.row.round', {
                        'amount': '−${formatMoney(row.round)}',
                      }),
                      color: PaykColors.primary,
                    ),
                  if (row.coupon > 0)
                    _RowChip(
                      text: tr(locale, 'receipts.row.coupon', {
                        'amount': '−${formatMoney(row.coupon)}',
                      }),
                      color: PaykColors.primary,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RowChip extends StatelessWidget {
  const _RowChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
