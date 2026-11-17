import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/i18n/locale_controller.dart';
import '../../core/i18n/strings.dart';
import '../../core/motion/payk_motion.dart';
import '../../core/theme/payk_colors.dart';
import '../../core/widgets/message.dart';
import '../../core/widgets/screen_skeletons.dart';
import '../../core/widgets/states.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/models.dart';
import '../../data/providers.dart';

/// Полная детализация электронного чека: товары, оплата, кэшбэк, возвраты, PDF/PNG и обращение.
class ReceiptDetailScreen extends ConsumerStatefulWidget {
  const ReceiptDetailScreen({super.key, required this.receiptId});

  final int receiptId;

  @override
  ConsumerState<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends ConsumerState<ReceiptDetailScreen> {
  String? _sharingKind;

  Future<void> _shareFile(ReceiptView receipt, String kind, String locale) async {
    if (_sharingKind != null) return;
    setState(() => _sharingKind = kind);
    try {
      final bytes = await ref
          .read(loyaltyApiProvider)
          .receiptFile(receipt.id, kind: kind);
      if (!mounted) return;
      final clean = receipt.number.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
      final name = 'chek-${clean.isNotEmpty ? clean : '${receipt.id}'}.$kind';
      final mimeType = kind == 'pdf' ? 'application/pdf' : 'image/png';
      final title = receipt.number.isNotEmpty
          ? tr(locale, 'receipts.title', {'number': receipt.number})
          : tr(locale, 'receipts.titleShort');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: name, mimeType: mimeType)],
          text: title,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      showPaykMessage(
        context,
        error is ApiException ? error.message : tr(locale, 'receipts.shareFail'),
      );
    } finally {
      if (mounted) setState(() => _sharingKind = null);
    }
  }

  Future<void> _openClaimSheet(ReceiptView receipt, String locale) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PaykColors.sheet,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ClaimSheet(receiptId: receipt.id, locale: locale),
    );
    if (submitted == true && mounted) {
      ref.invalidate(receiptDetailProvider(widget.receiptId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final async = ref.watch(receiptDetailProvider(widget.receiptId));
    final currentReceipt = async.asData?.value;

    final appBarTitle = currentReceipt != null && currentReceipt.number.isNotEmpty
        ? tr(locale, 'receipts.title', {'number': currentReceipt.number})
        : tr(locale, 'receipts.titleShort');

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
        ),
        title: Text(
          appBarTitle,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: PaykColors.textPrimary,
          ),
        ),
      ),
      body: AsyncView(
        value: async,
        onRetry: () => ref.invalidate(receiptDetailProvider(widget.receiptId)),
        loading: const HistorySkeleton(),
        data: (receipt) => _ReceiptDetailBody(
          receipt: receipt,
          locale: locale,
          sharingKind: _sharingKind,
          onSharePdf: () => _shareFile(receipt, 'pdf', locale),
          onSharePng: () => _shareFile(receipt, 'png', locale),
          onOpenClaim: () => _openClaimSheet(receipt, locale),
        ),
      ),
    );
  }
}

class _ReceiptDetailBody extends StatelessWidget {
  const _ReceiptDetailBody({
    required this.receipt,
    required this.locale,
    required this.sharingKind,
    required this.onSharePdf,
    required this.onSharePng,
    required this.onOpenClaim,
  });

  final ReceiptView receipt;
  final String locale;
  final String? sharingKind;
  final VoidCallback onSharePdf;
  final VoidCallback onSharePng;
  final VoidCallback onOpenClaim;

  String _formatLabel(String? fmt) {
    if (fmt == null || fmt.isEmpty) return '';
    final key = 'format.$fmt';
    final resolved = tr(locale, key);
    return resolved != key ? resolved : fmt;
  }

  String _modeLabel(String? mode) {
    if (mode == null || mode.isEmpty) return '';
    final key = 'pay.mode.$mode';
    final resolved = tr(locale, key);
    return resolved != key ? resolved : mode.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final store = (receipt.store != null && receipt.store!.trim().isNotEmpty)
        ? receipt.store!.trim()
        : tr(locale, 'receipts.titleShort');
    final fmtLabel = _formatLabel(receipt.format);
    final isReturned = receipt.state == 'returned';
    final isPartial = receipt.state == 'partially_returned';
    final linesPending = receipt.lines.isEmpty || receipt.itemsStatus != 'ok';

    return ListView(
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        28 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        // 1. Шапка чека
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: PaykColors.textPrimary,
                          ),
                        ),
                        if (fmtLabel.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            fmtLabel,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: PaykColors.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isReturned || isPartial)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: PaykColors.danger.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        tr(
                          locale,
                          isReturned
                              ? 'receipts.state.returned'
                              : 'receipts.state.partial',
                        ),
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: PaykColors.danger,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${formatDate(receipt.ts)} · ${formatTimeSeconds(receipt.ts)}',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: PaykColors.textSecondary,
                ),
              ),
              if (receipt.terminal != null && receipt.terminal!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  tr(locale, 'receipts.terminal', {'terminal': receipt.terminal!}),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    color: PaykColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. Товары
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(locale, 'receipts.lines'),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: PaykColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              if (linesPending)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: PaykColors.tile,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tr(locale, 'receipts.linesPending'),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: PaykColors.textSecondary,
                    ),
                  ),
                )
              else
                for (var i = 0; i < receipt.lines.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 16, thickness: 0.7, color: PaykColors.border),
                  _ReceiptLineTile(line: receipt.lines[i], locale: locale),
                ],
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 3. Итоги и оплата
        _Card(
          child: Column(
            children: [
              if (receipt.coupon > 0) ...[
                _KeyValueRow(
                  label: tr(locale, 'receipts.beforeCoupon'),
                  value: formatMoney(receipt.amountBeforeCoupon),
                ),
                const SizedBox(height: 8),
                _KeyValueRow(
                  label: tr(locale, 'receipts.coupon'),
                  value: '−${formatMoney(receipt.coupon)}',
                  valueColor: PaykColors.primary,
                ),
                const Divider(height: 18, thickness: 0.7, color: PaykColors.border),
              ],
              _KeyValueRow(
                label: tr(locale, 'receipts.total'),
                value: formatMoney(receipt.amount),
                bold: true,
              ),
              if (receipt.burn > 0) ...[
                const SizedBox(height: 8),
                _KeyValueRow(
                  label: tr(locale, 'receipts.burn'),
                  value: '−${formatMoney(receipt.burn)}',
                ),
              ],
              if (receipt.round > 0) ...[
                const SizedBox(height: 8),
                _KeyValueRow(
                  label: tr(locale, 'receipts.round'),
                  value: '−${formatMoney(receipt.round)}',
                  valueColor: PaykColors.primary,
                ),
              ],
              if (receipt.mode != null && receipt.mode!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _KeyValueRow(
                  label: tr(locale, 'pay.mode.label'),
                  value: _modeLabel(receipt.mode),
                ),
              ],
              if (receipt.cashPay > 0 || receipt.cardPay > 0)
                const Divider(height: 18, thickness: 0.7, color: PaykColors.border),
              if (receipt.cashPay > 0)
                _KeyValueRow(
                  label: tr(locale, 'receipts.payCash'),
                  value: formatMoney(receipt.cashPay),
                ),
              if (receipt.cashPay > 0 && receipt.cardPay > 0)
                const SizedBox(height: 8),
              if (receipt.cardPay > 0)
                _KeyValueRow(
                  label: tr(locale, 'receipts.payCard'),
                  value: formatMoney(receipt.cardPay),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4. Кэшбэк, статус и баланс после чека
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KeyValueRow(
                label: tr(locale, 'receipts.earn'),
                value: '+${formatMoney(receipt.earn)}',
                valueColor: receipt.earn > 0 ? PaykColors.success : PaykColors.textPrimary,
                bold: true,
              ),
              if (receipt.rate != null) ...[
                const SizedBox(height: 4),
                Text(
                  tr(locale, 'receipts.earnRate', {
                    'status': tierLabel(locale, receipt.rate!.status),
                    'format': fmtLabel.isNotEmpty
                        ? fmtLabel
                        : (receipt.format ?? ''),
                    'pct': formatRatePct(receipt.rate!.pct),
                  }),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PaykColors.textSecondary,
                  ),
                ),
              ],
              if (receipt.balanceAfter != null) ...[
                const SizedBox(height: 8),
                _KeyValueRow(
                  label: tr(locale, 'receipts.balance'),
                  value: formatMoney(receipt.balanceAfter!),
                ),
              ],
              if ((receipt.spendContribution ?? 0) > 0) ...[
                const SizedBox(height: 8),
                Text(
                  receipt.spendAfter != null
                      ? tr(locale, 'receipts.contrib', {
                          'amount': formatMoney(receipt.spendContribution!),
                          'total': formatMoney(receipt.spendAfter!),
                        })
                      : tr(locale, 'receipts.contribOnly', {
                          'amount': formatMoney(receipt.spendContribution!),
                        }),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: PaykColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),

        // 5. Возвраты
        if (receipt.returns.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(locale, 'receipts.returns'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: PaykColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < receipt.returns.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 18, thickness: 0.7, color: PaykColors.border),
                  _ReturnBlock(ret: receipt.returns[i], locale: locale),
                ],
              ],
            ),
          ),
        ],

        // 6. Обращение (Claim)
        if (receipt.claim != null) ...[
          const SizedBox(height: 12),
          _ClaimStatusCard(claim: receipt.claim!, locale: locale),
        ],

        const SizedBox(height: 16),

        // 7. Действия: PDF, PNG и кнопка обращения
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: sharingKind != null ? null : onSharePdf,
                icon: sharingKind == 'pdf'
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: Text(
                  tr(locale, 'receipts.pdf'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: PaykColors.primary,
                  side: const BorderSide(color: PaykColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: sharingKind != null ? null : onSharePng,
                icon: sharingKind == 'png'
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.image_outlined, size: 18),
                label: Text(
                  tr(locale, 'receipts.png'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: PaykColors.primary,
                  side: const BorderSide(color: PaykColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (receipt.claim == null) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: onOpenClaim,
            child: Text(
              tr(locale, 'receipts.claim.open'),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: PaykColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

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
      child: child,
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    required this.value,
    this.valueColor = PaykColors.textPrimary,
    this.bold = false,
  });

  final String label;
  final String value;
  final Color valueColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: bold ? 15 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
              color: bold ? PaykColors.textPrimary : PaykColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _ReceiptLineTile extends StatelessWidget {
  const _ReceiptLineTile({required this.line, required this.locale});

  final ReceiptLine line;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final fullRet = line.isFullReturned;
    final partialRet = line.isPartialReturned;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.name,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fullRet ? PaykColors.textMuted : PaykColors.textPrimary,
                  decoration: fullRet ? TextDecoration.lineThrough : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${formatQty(line.qty, line.unit)} × ${formatMoney(line.price)}',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  color: PaykColors.textSecondary,
                ),
              ),
              if (fullRet || partialRet) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: PaykColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    fullRet
                        ? tr(locale, 'receipts.line.returned')
                        : tr(locale, 'receipts.line.partial', {
                            'qty': formatQty(line.returnedQty, line.unit),
                            'amount': formatMoney(line.returnedAmount),
                          }),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: PaykColors.danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          formatMoney(line.amount),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: fullRet ? PaykColors.textMuted : PaykColors.textPrimary,
            decoration: fullRet ? TextDecoration.lineThrough : null,
          ),
        ),
      ],
    );
  }
}

class _ReturnBlock extends StatelessWidget {
  const _ReturnBlock({required this.ret, required this.locale});

  final ReceiptReturn ret;
  final String locale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${formatShortDate(ret.ts)} · ${formatTime(ret.ts)}',
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: PaykColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        _KeyValueRow(
          label: tr(locale, 'receipts.ret.amount'),
          value: '−${formatMoney(ret.amount)}',
          valueColor: PaykColors.danger,
          bold: true,
        ),
        if (ret.reversedEarn > 0) ...[
          const SizedBox(height: 4),
          _KeyValueRow(
            label: tr(locale, 'receipts.ret.earn'),
            value: '−${formatMoney(ret.reversedEarn)}',
          ),
        ],
        if (ret.refundedBurn > 0) ...[
          const SizedBox(height: 4),
          _KeyValueRow(
            label: tr(locale, 'receipts.ret.burn'),
            value: '+${formatMoney(ret.refundedBurn)}',
            valueColor: PaykColors.success,
          ),
        ],
        if (ret.refundedRound > 0) ...[
          const SizedBox(height: 4),
          _KeyValueRow(
            label: tr(locale, 'receipts.ret.round'),
            value: '+${formatMoney(ret.refundedRound)}',
          ),
        ],
        if (ret.lines.isEmpty && ret.linesState != 'ok') ...[
          const SizedBox(height: 6),
          Text(
            tr(locale, 'receipts.ret.linesPending'),
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: PaykColors.textMuted,
            ),
          ),
        ] else if (ret.lines.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            tr(locale, 'receipts.ret.lines'),
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: PaykColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          for (final line in ret.lines) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${line.name} · ${formatQty(line.qty, line.unit)}',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      color: PaykColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '−${formatMoney(line.amount)}',
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: PaykColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
          ],
        ],
      ],
    );
  }
}

class _ClaimStatusCard extends StatelessWidget {
  const _ClaimStatusCard({required this.claim, required this.locale});

  final ReceiptClaim claim;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final open = claim.isOpen;
    final accepted = claim.decision == 'accepted';
    final statusColor = open
        ? PaykColors.primary
        : (accepted ? PaykColors.success : PaykColors.danger);
    final statusText = open
        ? tr(locale, 'receipts.claim.open.status')
        : tr(locale, accepted ? 'receipts.claim.accepted' : 'receipts.claim.rejected');
    final kindKey = 'receipts.claim.${claim.kind}';
    final kindText = tr(locale, kindKey) != kindKey ? tr(locale, kindKey) : claim.kind;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  tr(locale, 'receipts.claim.status'),
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: PaykColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            kindText,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: PaykColors.textPrimary,
            ),
          ),
          if (claim.text != null && claim.text!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              claim.text!,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: PaykColors.textSecondary,
              ),
            ),
          ],
          if (open && claim.dueAt != null) ...[
            const SizedBox(height: 6),
            Text(
              tr(locale, 'receipts.claim.open.due', {
                'date': formatDate(claim.dueAt!),
              }),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                color: PaykColors.textMuted,
              ),
            ),
          ],
          if (claim.answer != null && claim.answer!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: PaykColors.tile,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                tr(locale, 'receipts.claim.answer', {'text': claim.answer!}),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PaykColors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClaimSheet extends ConsumerStatefulWidget {
  const _ClaimSheet({required this.receiptId, required this.locale});

  final int receiptId;
  final String locale;

  @override
  ConsumerState<_ClaimSheet> createState() => _ClaimSheetState();
}

class _ClaimSheetState extends ConsumerState<_ClaimSheet> {
  final TextEditingController _ctrl = TextEditingController();
  String _kind = 'items';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(loyaltyApiProvider).claimReceipt(
            widget.receiptId,
            kind: _kind,
            text: _ctrl.text.trim(),
          );
      if (!mounted) return;
      showPaykMessage(context, tr(widget.locale, 'receipts.claim.sent'));
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      if (error.status == 409) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = tr(widget.locale, 'receipts.loadError'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    const kinds = ['not_mine', 'items', 'cashback'];

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: PaykColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              tr(locale, 'receipts.claim.title'),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: PaykColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr(locale, 'receipts.claim.kind'),
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PaykColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            for (final kind in kinds) ...[
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _kind = kind),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: _kind == kind ? PaykColors.activePill : PaykColors.tile,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _kind == kind ? PaykColors.primary : PaykColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _kind == kind
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        size: 18,
                        color: _kind == kind
                            ? PaykColors.primary
                            : PaykColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          tr(locale, 'receipts.claim.$kind'),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: PaykColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '${tr(locale, 'receipts.claim.text')} (${tr(locale, 'common.optional')})',
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: PaykColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrl,
              maxLength: 1000,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: tr(locale, 'receipts.claim.placeholder'),
                filled: true,
                fillColor: PaykColors.tile,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: PaykColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: PaykColors.border),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: PaykColors.danger,
                ),
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _sending ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: PaykColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _sending
                    ? tr(locale, 'profile.saving')
                    : tr(locale, 'receipts.claim.send'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
