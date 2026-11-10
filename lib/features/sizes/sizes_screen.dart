import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/message.dart';
import '../../core/widgets/states.dart';
import '../../data/api/api_exception.dart';
import '../../data/providers.dart';

const shoeSizes = [
  '36', '37', '38', '39', '40', '41', '42', '43', '44', '45', '46',
  '36.5', '37.5', '38.5', '39.5', '40.5', '41.5', '42.5', '43.5', '44.5', '45.5',
];

const pantsSizes = [
  '28', '30', '32', '34', '36', '38', '40', '42', '44', '46', '48', '50', '52', '54', '56', '58', '60',
  'S', 'M', 'L', 'XL', '2XL', '3XL',
];

const topSizes = [
  'S', 'M', 'L', 'XL', '2XL', '3XL', '4XL',
  '46', '48', '50', '52', '54', '56', '58', '60',
];

/// Три размера в том же виде, что и остальные карточки профиля.
class SizesScreen extends ConsumerStatefulWidget {
  const SizesScreen({super.key});

  @override
  ConsumerState<SizesScreen> createState() => _SizesScreenState();
}

class _SizesScreenState extends ConsumerState<SizesScreen> {
  String? _shoe;
  String? _pants;
  String? _top;
  var _ready = false;
  var _saving = false;
  String? _error;

  void _take(String? shoe, String? pants, String? top) {
    if (_ready) return;
    _shoe = shoe;
    _pants = pants;
    _top = top;
    _ready = true;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(loyaltyApiProvider).updateSizes(shoe: _shoe, pants: _pants, top: _top);
      ref.invalidate(meProvider);
      if (!mounted) return;
      showPaykMessage(context, tr(ref.read(localeProvider), 'sizes.saved'));
      Navigator.of(context).maybePop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error is ApiException ? error.message : tr(ref.read(localeProvider), 'sizes.failed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    return Scaffold(
      backgroundColor: PaykColors.canvas,
      appBar: AppBar(
        backgroundColor: PaykColors.canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: PaykPressable(
          scaleDown: PaykMotion.scaleIcon,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: PaykColors.textPrimary, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).maybePop();
            },
          ),
        ),
        title: Text(
          tr(locale, 'sizes.title'),
          style: const TextStyle(
            color: PaykColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            fontFamily: 'Manrope',
          ),
        ),
      ),
      body: AsyncView(
        value: ref.watch(meProvider),
        onRetry: () => ref.invalidate(meProvider),
        data: (account) {
          final member = account.member;
          _take(member.shoeSize, member.pantsSize, member.topSize);
          return ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              Text(
                tr(locale, 'sizes.lead'),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: PaykColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _SizeGroup(
                title: tr(locale, 'sizes.shoe'),
                values: shoeSizes,
                selected: _shoe,
                onPick: (value) => setState(() => _shoe = value),
              ),
              const SizedBox(height: 16),
              _SizeGroup(
                title: tr(locale, 'sizes.pants'),
                values: pantsSizes,
                selected: _pants,
                onPick: (value) => setState(() => _pants = value),
              ),
              const SizedBox(height: 16),
              _SizeGroup(
                title: tr(locale, 'sizes.top'),
                values: topSizes,
                selected: _top,
                onPick: (value) => setState(() => _top = value),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: PaykColors.danger, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: PaykColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(_saving ? tr(locale, 'profile.saving') : tr(locale, 'sizes.save')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SizeGroup extends StatelessWidget {
  const _SizeGroup({
    required this.title,
    required this.values,
    required this.selected,
    required this.onPick,
  });

  final String title;
  final List<String> values;
  final String? selected;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PaykColors.sheet,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PaykColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: PaykColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                _SizeChip(
                  label: value,
                  selected: selected == value,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onPick(value);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PaykPressable(
      scaleDown: PaykMotion.scaleIcon,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? PaykColors.primary : PaykColors.tile,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? PaykColors.primary : PaykColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : PaykColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
