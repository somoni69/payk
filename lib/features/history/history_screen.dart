import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/states.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

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
  });

  final String? initialCategory;

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  late HistoryCategory _selectedCategory;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedCategory = _parseCategory(widget.initialCategory);
    _searchController.addListener(_onSearchChanged);
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
    return entries.where((entry) {
      // 1. Фильтрация по выбранной категории
      switch (_selectedCategory) {
        case HistoryCategory.all:
          break;
        case HistoryCategory.purchases:
          final isPurchase = entry.billAmount != null ||
              entry.type == 'purchase' ||
              entry.type == 'burn' ||
              entry.mode == 'supermarket' ||
              entry.mode == 'clothes';
          if (!isPurchase) return false;
        case HistoryCategory.accrual:
          final isAccrual = entry.type == 'accrual' ||
              (entry.amount > 0 && entry.type != 'referral');
          if (!isAccrual) return false;
        case HistoryCategory.burn:
          final isBurn = entry.type == 'burn' ||
              (entry.mode != null && entry.amount < 0);
          if (!isBurn) return false;
        case HistoryCategory.returns:
          final isReturn = entry.type == 'refund' || entry.type == 'reversal';
          if (!isReturn) return false;
        case HistoryCategory.friends:
          final isFriend = entry.type == 'referral' ||
              entry.type == 'referral_reversal';
          if (!isFriend) return false;
      }

      // 2. Фильтрация по поисковому запросу
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      if (entry.id.toString().contains(q)) return true;
      if (entry.type.toLowerCase().contains(q)) return true;
      if (entry.note != null && entry.note!.toLowerCase().contains(q)) return true;
      if (entry.format != null && entry.format!.toLowerCase().contains(q)) return true;
      if (entry.mode != null && entry.mode!.toLowerCase().contains(q)) return true;
      if (formatMoney(entry.amount).toLowerCase().contains(q)) return true;
      if (entry.billAmount != null &&
          formatMoney(entry.billAmount!).toLowerCase().contains(q)) {
        return true;
      }
      return false;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final historyAsync = ref.watch(historyProvider);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: PaykColors.canvas,
      appBar: AppBar(
        backgroundColor: PaykColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 68,
        titleSpacing: canPop ? 4 : 16,
        leading: canPop
            ? PaykPressable(
                scaleDown: PaykMotion.scaleIcon,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: PaykColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).maybePop();
                  },
                ),
              )
            : null,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _SearchField(
            controller: _searchController,
            hint: tr(locale, 'history.search'),
            showClear: _searchQuery.isNotEmpty,
            onClear: _clearSearch,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: AsyncView(
          value: historyAsync,
          onRetry: () => ref.invalidate(historyProvider),
          loading: const HistorySkeleton(),
          data: (allEntries) {
            final filteredEntries = _filterEntries(allEntries);
            final isFiltered = _selectedCategory != HistoryCategory.all ||
                _searchQuery.isNotEmpty;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
              physics: const ClampingScrollPhysics(),
              children: [
                // Секция категорий (Категорияҳо / Категории)
                Text(
                  tr(locale, 'history.categories'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
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
                        isSelected: _selectedCategory == HistoryCategory.purchases,
                        title: tr(locale, 'history.cat.purchases'),
                        onTap: () => _pickCategory(HistoryCategory.purchases),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CategoryTile(
                        category: HistoryCategory.accrual,
                        isSelected: _selectedCategory == HistoryCategory.accrual,
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
                        isSelected: _selectedCategory == HistoryCategory.returns,
                        title: tr(locale, 'history.cat.returns'),
                        onTap: () => _pickCategory(HistoryCategory.returns),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CategoryTile(
                        category: HistoryCategory.friends,
                        isSelected: _selectedCategory == HistoryCategory.friends,
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
                  child: filteredEntries.isEmpty
                      ? KeyedSubtree(
                          key: ValueKey('empty_${_selectedCategory.key}_$isFiltered'),
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
                            border: Border.all(color: PaykColors.border, width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (var i = 0; i < filteredEntries.length; i++) ...[
                                if (i > 0)
                                  const Divider(
                                    height: 1,
                                    thickness: 1,
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
              ],
            );
          },
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
  });

  final TextEditingController controller;
  final String hint;
  final bool showClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: PaykColors.textPrimary,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: PaykColors.textSecondary,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: PaykColors.textSecondary,
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
          fillColor: PaykColors.surfaceNested,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
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
    return PaykPressable(
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
                      fontFamily: 'Manrope',
                      fontSize: 13.5,
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
    );
  }
}

/// Карточка пустого состояния с 3D-чеком
class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard({
    required this.isFiltered,
    required this.locale,
  });

  final bool isFiltered;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              fontFamily: 'Manrope',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: PaykColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(locale, isFiltered ? 'history.notFoundText' : 'history.emptyText'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Manrope',
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
  const _HistoryRow({
    required this.entry,
    required this.locale,
  });

  final HistoryEntry entry;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final positive = entry.amount >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: positive
                  ? PaykColors.incomeSoft
                  : PaykColors.expenseSoft,
            ),
            alignment: Alignment.center,
            child: Icon(
              positive
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 20,
              color: positive
                  ? PaykColors.success
                  : PaykColors.bad,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(locale, 'history.type.${_known(entry.type)}'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: PaykColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    formatDate(entry.createdAt),
                    if (entry.billAmount != null)
                      tr(locale, 'history.billAmount', {
                        'amount': formatMoney(entry.billAmount!),
                      }),
                    if (entry.format == 'SM') tr(locale, 'format.SM'),
                    if (entry.format == 'CL') tr(locale, 'format.CL'),
                  ].join(' · '),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    color: PaykColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatMoney(entry.amount, signed: true),
            style: TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w700,
              fontSize: 16,
              letterSpacing: -0.2,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: positive
                  ? PaykColors.success
                  : PaykColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

String _known(String type) {
  const known = {
    'accrual',
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
