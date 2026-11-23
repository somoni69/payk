import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/payment_choice.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/payk_3d_icon.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';
import 'receipts_tab.dart';

enum HistoryTab { ops, bills }

/// Категории фильтрации операций
enum HistoryCategory {
  all('all', 'receipt'),
  purchases('purchases', 'bags'),
  accrual('accrual', 'coin'),
  burn('burn', 'card'),
  returns('returns', 'basket'),
  friends('friends', 'gift');

  const HistoryCategory(this.key, this.image);
  final String key;
  final String image;
}

/// Экран «Харидҳо / Покупки» (Purchases & Operations) в стиле Payk / UDC Ecosystem.
/// Полностью соответствует дизайну из loyalty-app:
/// 1. Верхнее поле поиска по номеру чека («Ҷустуҷӯ аз рӯи рақами чек» / «Поиск по номеру чека»).
/// 2. Секция «Категорияҳо / Категории» из 6 интерактивных 3D-плиток (3x2):
///    - «Ҳамаи амалиётҳо» (receipt.webp)
///    - «Харидҳо» (bags.webp)
///    - «Кэшбэк» (coin.webp)
///    - «Бо бонус» (card.webp)
///    - «Бозпас» (basket.webp)
///    - «Аз дӯстон» (gift.webp)
/// 3. Фильтрация операций в реальном времени по выбранной категории и строке поиска.
/// 4. Карточка пустого состояния с 3D-чеком («Ҳанӯз амалиёт нест») или список транзакций.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({
    super.key,
    this.initialCategory,
    this.initialTab = HistoryTab.ops,
  });

  final String? initialCategory;
  final HistoryTab initialTab;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  late HistoryTab _tab;
  late HistoryCategory _selectedCategory;
  String _searchQuery = '';
  final List<HistoryEntry> _extra = [];
  var _loadingMore = false;
  var _moreDone = false;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _selectedCategory = _parseCategory(widget.initialCategory);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _tab = widget.initialTab;
    }
  }

  static HistoryCategory _parseCategory(String? key) {
    if (key == null) return HistoryCategory.all;
    for (final c in HistoryCategory.values) {
      if (c.key == key) return c;
    }
    return HistoryCategory.all;
  }

  void _onSearchChanged() {
    final text = _searchController.text.trim();
    if (text != _searchQuery) {
      setState(() {
        _searchQuery = text;
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });
  }

  void _pickCategory(HistoryCategory category) {
    if (_selectedCategory != category) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedCategory = category;
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<HistoryEntry> _filterEntries(List<HistoryEntry> entries) {
    return entries
        .where((entry) {
          if (!historyTypeInCategory(entry.type, _selectedCategory.key)) {
            return false;
          }
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          if (entry.id.toString().contains(q)) return true;
          if (entry.billExtId != null && entry.billExtId!.toLowerCase().contains(q)) {
            return true;
          }
          if (entry.type.toLowerCase().contains(q)) return true;
          if (entry.note != null && entry.note!.toLowerCase().contains(q)) {
            return true;
          }
          if (entry.format != null && entry.format!.toLowerCase().contains(q)) {
            return true;
          }
          if (entry.mode != null && entry.mode!.toLowerCase().contains(q)) {
            return true;
          }
          if (formatMoney(entry.amount).toLowerCase().contains(q)) return true;
          if (entry.billAmount != null &&
              formatMoney(entry.billAmount!).toLowerCase().contains(q)) {
            return true;
          }
          return false;
        })
        .toList(growable: false);
  }

  Future<void> _loadMore(List<HistoryEntry> loaded) async {
    if (_loadingMore || loaded.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(loyaltyApiProvider)
          .history(beforeId: loaded.last.id);
      if (!mounted) return;
      final seen = loaded.map((entry) => entry.id).toSet();
      setState(() {
        _extra.addAll(page.where((entry) => !seen.contains(entry.id)));
        _moreDone = page.length < 50;
      });
    } catch (_) {
      // Список уже открытых операций остаётся на экране.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _searchOnServer() async {
    final query = _searchQuery;
    if (query.isEmpty) return;
    try {
      final page = await ref.read(loyaltyApiProvider).history(query: query);
      if (!mounted || query != _searchQuery) return;
      final seen = _extra.map((entry) => entry.id).toSet();
      setState(() {
        _extra.addAll(page.where((entry) => !seen.contains(entry.id)));
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final historyAsync = ref.watch(historyProvider);
    final canPop = Navigator.of(context).canPop();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: PaykColors.canvas,
        body: Column(
          children: [
            _HistoryHeader(
              tab: _tab,
              canPop: canPop,
              locale: locale,
              searchController: _searchController,
              showClear: _searchQuery.isNotEmpty,
              onClear: _clearSearch,
              onSubmit: _searchOnServer,
              onTabChanged: (next) {
                if (_tab == next) return;
                HapticFeedback.selectionClick();
                setState(() => _tab = next);
              },
            ),
            Expanded(
              child: SafeArea(
                top: false,
                bottom: false,
                child: AnimatedSwitcher(
                  duration: PaykMotion.duration(context, PaykMotion.normal),
                  switchInCurve: PaykMotion.easeOut,
                  switchOutCurve: PaykMotion.easeOut,
                  layoutBuilder: PaykMotion.topAlignedLayoutBuilder,
                  transitionBuilder: (child, animation) {
                    final offset = Tween<Offset>(
                      begin: const Offset(0, 0.015),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: offset,
                        child: RepaintBoundary(child: child),
                      ),
                    );
                  },
                  child: _tab == HistoryTab.bills
                      ? const KeyedSubtree(
                          key: ValueKey('tab_bills'),
                          child: ReceiptsTab(),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('tab_ops'),
                          child: AsyncView(
                            value: historyAsync,
                            onRetry: () => ref.invalidate(historyProvider),
                            loading: const HistorySkeleton(),
                            data: (allEntries) {
              final loaded = [...allEntries, ..._extra];
              final filteredEntries = _filterEntries(loaded);
              final showMore = !_moreDone && allEntries.length >= 50;
              final isFiltered =
                  _selectedCategory != HistoryCategory.all ||
                  _searchQuery.isNotEmpty;

              return RefreshIndicator(
                color: PaykColors.violet,
                backgroundColor: Colors.white,
                onRefresh: () async {
                  setState(() {
                    _extra.clear();
                    _moreDone = false;
                  });
                  ref.invalidate(historyProvider);
                  try {
                    await ref.read(historyProvider.future);
                  } catch (_) {}
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    // Секция категорий (Категорияҳо / Категории)
                    Text(
                      tr(locale, 'history.categories'),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: PaykColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Сетка из 6 интерактивных 3D-плиток (3x2)
                    Row(
                      children: [
                        Expanded(
                          child: _CategoryTile(
                            category: HistoryCategory.all,
                            isSelected: _selectedCategory == HistoryCategory.all,
                            title: tr(locale, 'history.cat.all'),
                            onTap: () => _pickCategory(HistoryCategory.all),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CategoryTile(
                            category: HistoryCategory.purchases,
                            isSelected:
                                _selectedCategory == HistoryCategory.purchases,
                            title: tr(locale, 'history.cat.purchases'),
                            onTap: () => _pickCategory(HistoryCategory.purchases),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CategoryTile(
                            category: HistoryCategory.accrual,
                            isSelected:
                                _selectedCategory == HistoryCategory.accrual,
                            title: tr(locale, 'history.cat.accrual'),
                            onTap: () => _pickCategory(HistoryCategory.accrual),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _CategoryTile(
                            category: HistoryCategory.burn,
                            isSelected: _selectedCategory == HistoryCategory.burn,
                            title: tr(locale, 'history.cat.burn'),
                            onTap: () => _pickCategory(HistoryCategory.burn),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CategoryTile(
                            category: HistoryCategory.returns,
                            isSelected:
                                _selectedCategory == HistoryCategory.returns,
                            title: tr(locale, 'history.cat.returns'),
                            onTap: () => _pickCategory(HistoryCategory.returns),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _CategoryTile(
                            category: HistoryCategory.friends,
                            isSelected:
                                _selectedCategory == HistoryCategory.friends,
                            title: tr(locale, 'history.cat.friends'),
                            onTap: () => _pickCategory(HistoryCategory.friends),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // 3. Список операций или карточка пустого состояния
                    AnimatedSwitcher(
                      duration: PaykMotion.duration(context, PaykMotion.normal),
                      switchInCurve: PaykMotion.easeOut,
                      switchOutCurve: PaykMotion.easeOut,
                      layoutBuilder: PaykMotion.topAlignedLayoutBuilder,
                      child: filteredEntries.isEmpty
                          ? KeyedSubtree(
                              key: ValueKey(
                                'empty_${_selectedCategory.key}_$isFiltered',
                              ),
                              child: _EmptyHistoryCard(
                                isFiltered: isFiltered,
                                locale: locale,
                              ),
                            )
                          : Container(
                              key: ValueKey('list_${_selectedCategory.key}'),
                              decoration: BoxDecoration(
                                color: PaykColors.sheet,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: PaykColors.border,
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 12,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  for (
                                    var i = 0;
                                    i < filteredEntries.length;
                                    i++
                                  ) ...[
                                    if (i > 0)
                                      const Divider(
                                        height: 1,
                                        thickness: 1,
                                        indent: 70,
                                        endIndent: 14,
                                        color: PaykColors.border,
                                      ),
                                    _HistoryRow(
                                      entry: filteredEntries[i],
                                      locale: locale,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                    ),
                    if (showMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextButton(
                          onPressed: _loadingMore
                              ? null
                              : () => _loadMore(loaded),
                          child: Text(
                            tr(
                              locale,
                              _loadingMore ? 'history.loading' : 'history.more',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Градиентная шапка раздела истории со скруглением PaykRadius.header,
/// совпадающая с шапками Главной, «PAYK для бизнеса» и «Приглашайте друзей».
class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.tab,
    required this.canPop,
    required this.locale,
    required this.searchController,
    required this.showClear,
    required this.onClear,
    required this.onSubmit,
    required this.onTabChanged,
  });

  final HistoryTab tab;
  final bool canPop;
  final String locale;
  final TextEditingController searchController;
  final bool showClear;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final ValueChanged<HistoryTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final dur = PaykMotion.duration(context, PaykMotion.fast);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: PaykColors.headerGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(PaykRadius.header),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 46,
                child: AnimatedSwitcher(
                  duration: dur,
                  switchInCurve: PaykMotion.easeOut,
                  switchOutCurve: PaykMotion.easeOut,
                  child: tab == HistoryTab.ops
                      ? Row(
                          key: const ValueKey('header_ops'),
                          children: [
                            if (canPop) ...[
                              _HeaderBackButton(
                                onTap: () => Navigator.of(context).maybePop(),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: _SearchField(
                                controller: searchController,
                                hint: tr(locale, 'history.search'),
                                showClear: showClear,
                                onClear: onClear,
                                onSubmit: onSubmit,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          key: const ValueKey('header_bills'),
                          children: [
                            if (canPop) ...[
                              _HeaderBackButton(
                                onTap: () => Navigator.of(context).maybePop(),
                              ),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: Text(
                                tr(locale, 'profile.purchases'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              _HistoryTabBar(
                tab: tab,
                opsLabel: tr(locale, 'history.tab.ops'),
                billsLabel: tr(locale, 'history.tab.bills'),
                onChanged: onTabChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderBackButton extends StatelessWidget {
  const _HeaderBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PaykPressable(
      scaleDown: PaykMotion.scaleIcon,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: PaykColors.headerButtonBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryTabBar extends StatelessWidget {
  const _HistoryTabBar({
    required this.tab,
    required this.opsLabel,
    required this.billsLabel,
    required this.onChanged,
  });

  final HistoryTab tab;
  final String opsLabel;
  final String billsLabel;
  final ValueChanged<HistoryTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final isOps = tab == HistoryTab.ops;
    final dur = PaykMotion.duration(context, PaykMotion.fast);

    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: isOps ? Alignment.centerLeft : Alignment.centerRight,
            duration: dur,
            curve: PaykMotion.easeSpring,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              heightFactor: 1,
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              _SegmentTab(
                label: opsLabel,
                selected: isOps,
                duration: dur,
                onTap: () => onChanged(HistoryTab.ops),
              ),
              _SegmentTab(
                label: billsLabel,
                selected: !isOps,
                duration: dur,
                onTap: () => onChanged(HistoryTab.bills),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.label,
    required this.selected,
    required this.duration,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PaykPressable(
        scaleDown: PaykMotion.scaleButton,
        onTap: onTap,
        child: Container(
          color: Colors.transparent,
          alignment: Alignment.center,
          child: AnimatedDefaultTextStyle(
            duration: duration,
            curve: PaykMotion.easeOut,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected
                  ? PaykColors.primary
                  : Colors.white.withValues(alpha: 0.90),
            ),
            child: Text(label, textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.showClear,
    required this.onClear,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String hint;
  final bool showClear;
  final VoidCallback onClear;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SizedBox(
        height: 46,
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSubmit(),
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: PaykColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
              color: PaykColors.textSecondary,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: PaykColors.primary,
              size: 20,
            ),
            suffixIcon: showClear
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: PaykColors.textSecondary,
                      size: 18,
                    ),
                    onPressed: onClear,
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Плитка категории с 3D-иконкой в правом нижнем углу
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.isSelected,
    required this.title,
    required this.onTap,
  });

  final HistoryCategory category;
  final bool isSelected;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: PaykPressable(
        scaleDown: PaykMotion.scaleButton,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: PaykMotion.duration(context, PaykMotion.fast),
              curve: PaykMotion.easeOut,
              height: 100,
              decoration: BoxDecoration(
                color: isSelected
                    ? PaykColors.activePill
                    : PaykColors.surfaceNested,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? PaykColors.primary : Colors.transparent,
                  width: 2.0,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.0,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? PaykColors.primary
                            : PaykColors.textPrimary,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: AnimatedScale(
                      scale: isSelected ? 1.07 : 1.0,
                      duration: PaykMotion.duration(context, PaykMotion.fast),
                      curve: PaykMotion.easeOut,
                      child: Image.asset(
                        'assets/3d/${category.image}.webp',
                        width: 48,
                        height: 48,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Карточка пустого состояния с 3D-чеком
class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard({required this.isFiltered, required this.locale});

  final bool isFiltered;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 24),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PaykColors.border, width: 1.0),
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
            tr(locale, isFiltered ? 'history.notFound' : 'history.empty'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: PaykColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              locale,
              isFiltered ? 'history.notFoundText' : 'history.emptyText',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: PaykColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Строка одной операции
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, required this.locale});

  final HistoryEntry entry;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final positive = entry.amount >= 0;
    final accentColor = positive ? PaykColors.success : PaykColors.danger;
    final softBg = positive ? PaykColors.incomeSoft : PaykColors.expenseSoft;
    final formatLabel = entry.format == 'SM'
        ? tr(locale, 'format.SM')
        : entry.format == 'CL'
            ? tr(locale, 'format.CL')
            : null;
    final billMeta = [
      if (entry.billExtId != null) '№ ${entry.billExtId}',
      if (entry.billAmount != null)
        tr(locale, 'history.billAmount', {
          'amount': formatMoney(entry.billAmount!),
        }),
    ].join(' · ');
    final hasMeta = formatLabel != null || billMeta.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: softBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.14),
              ),
            ),
            alignment: Alignment.center,
            child: positive
                ? const CashbackPlus3dIcon(
                    size: 28,
                    fallbackColor: PaykColors.success,
                  )
                : const CashbackMinus3dIcon(
                    size: 28,
                    fallbackColor: PaykColors.bad,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          _historyEntryTitle(locale, entry),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                            height: 1.25,
                            letterSpacing: -0.15,
                            color: PaykColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: softBg,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        formatMoney(entry.amount, signed: true),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                          letterSpacing: -0.2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      formatDate(entry.createdAt),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: PaykColors.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      tr(locale, 'history.balanceAfter', {
                        'amount': formatMoney(entry.balanceAfter),
                      }),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        color: PaykColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                if (hasMeta) ...[
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (formatLabel != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: PaykColors.activePill,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            formatLabel,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: PaykColors.primary,
                            ),
                          ),
                        ),
                      if (billMeta.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: PaykColors.surfaceNested,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            billMeta,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: PaykColors.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _historyEntryTitle(String locale, HistoryEntry entry) {
  final known = _known(entry.type);
  if (known != 'other') {
    return tr(locale, 'history.type.$known');
  }
  return tr(
    locale,
    entry.amount >= 0 ? 'history.type.otherIncome' : 'history.type.otherExpense',
  );
}

String _known(String type) {
  const known = {
    'accrual',
    'bonus',
    'welcome',
    'burn',
    'round',
    'referral',
    'referral_reversal',
    'reversal',
    'refund',
    'adjustment',
    'expiry',
    'debt',
  };
  return known.contains(type) ? type : 'other';
}
