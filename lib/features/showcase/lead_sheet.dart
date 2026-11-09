import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

const _companyMax = 160;

/// «Хочу PAYK»: имя и номер из профиля, название бизнеса — по желанию.
Future<void> showPaykLeadSheet({
  required BuildContext context,
  required int? cardId,
  required ShowcaseContact contact,
  required VoidCallback onSent,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: PaykColors.sheet,
    sheetAnimationStyle: PaykMotion.sheetAnimationStyle,
    builder: (context) {
      return PaykLeadSheet(cardId: cardId, contact: contact, onSent: onSent);
    },
  );
}

class PaykLeadSheet extends ConsumerStatefulWidget {
  const PaykLeadSheet({
    super.key,
    required this.cardId,
    required this.contact,
    required this.onSent,
  });

  final int? cardId;
  final ShowcaseContact contact;
  final VoidCallback onSent;

  @override
  ConsumerState<PaykLeadSheet> createState() => _PaykLeadSheetState();
}

class _PaykLeadSheetState extends ConsumerState<PaykLeadSheet> {
  final _company = TextEditingController();
  var _busy = false;
  String? _error;
  String? _result;

  @override
  void dispose() {
    _company.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || _result != null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(loyaltyApiProvider)
          .showcaseLead(widget.cardId, _company.text.trim());
      if (result.status != 'sent' && result.status != 'already') {
        throw ApiException(0, 'Неожиданный ответ сервера');
      }
      widget.onSent();
      if (!mounted) return;
      setState(() => _result = result.status);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final phone = formatPhone(widget.contact.phone);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + MediaQuery.paddingOf(context).bottom,
          ),
          child: _result == null ? _form(locale, phone) : _done(locale, phone),
        ),
      ),
    );
  }

  Widget _form(String locale, String phone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Handle(),
        Text(
          tr(locale, 'payk.sheetTitle'),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: PaykColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(locale, 'payk.sheetText'),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.45,
            color: PaykColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        _ContactCard(locale: locale, name: widget.contact.name, phone: phone),
        const SizedBox(height: 16),
        Text.rich(
          TextSpan(
            text: tr(locale, 'payk.company'),
            children: [
              TextSpan(
                text: ' · ${tr(locale, 'common.optional')}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: PaykColors.textMuted,
                ),
              ),
            ],
          ),
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: PaykColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('lead-company'),
          controller: _company,
          enabled: !_busy,
          maxLength: _companyMax,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.send,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: tr(locale, 'payk.companyPh'),
            counterText: '',
            errorText: _error,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => Navigator.of(context).maybePop(),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
                child: Text(tr(locale, 'common.cancel')),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                key: const Key('lead-send'),
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(minimumSize: const Size(0, 54)),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(tr(locale, 'payk.send')),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _done(String locale, String phone) {
    final sent = _result == 'sent';
    return Column(
      key: const Key('lead-done'),
      children: [
        const _Handle(),
        Image.asset(
          sent ? 'assets/3d/party.webp' : 'assets/3d/telephone.webp',
          height: 96,
          width: 96,
        ),
        const SizedBox(height: 12),
        Text(
          tr(locale, sent ? 'payk.doneTitle' : 'payk.alreadyTitle'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.2,
            color: PaykColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(locale, sent ? 'payk.doneText' : 'payk.alreadyText', {
            'phone': phone,
          }),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.45,
            color: PaykColors.textSecondary,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('lead-ok'),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).maybePop();
          },
          child: Text(tr(locale, 'payk.ok')),
        ),
      ],
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 6,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFE3E1EC),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.locale,
    required this.name,
    required this.phone,
  });

  final String locale;
  final String name;
  final String phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('lead-contact'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PaykColors.tile,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: PaykColors.brandSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_rounded,
              color: PaykColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(locale, 'payk.callTo'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PaykColors.textSecondary,
                  ),
                ),
                if (name.isNotEmpty)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: PaykColors.textPrimary,
                    ),
                  ),
                Text(
                  phone,
                  maxLines: 1,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: PaykColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
