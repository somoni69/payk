import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_exception.dart';
import '../theme/payk_colors.dart';
import 'shimmer.dart';

export 'shimmer.dart' show SkeletonBox, ShimmerSweep;

class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.onRetry,
    required this.data,
    this.loading,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) data;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final inset = EdgeInsets.only(top: pad.top, bottom: pad.bottom);
    return value.when(
      skipLoadingOnReload: true,
      loading: () => loading ?? Padding(padding: inset, child: const PaykLoading()),
      error: (error, stackTrace) => Padding(
        padding: inset,
        child: ErrorState(
          message: errorText(error),
          onRetry: onRetry,
        ),
      ),
      data: data,
    );
  }
}

class PaykLoading extends StatelessWidget {
  const PaykLoading({super.key, this.onColor});

  final Color? onColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ShimmerSweep(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonBox(height: 188, radius: 30, color: onColor),
              const SizedBox(height: 16),
              SkeletonBox(height: 54, radius: 16, color: onColor),
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.body,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String body;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: PaykColors.activePill,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                icon ?? Icons.inbox_outlined,
                size: 38,
                color: PaykColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: PaykColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 290),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  color: PaykColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: PaykColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(180, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    this.actionLabel = 'Повторить',
  });

  final String message;
  final VoidCallback onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: PaykColors.expenseSoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: PaykColors.bad.withValues(alpha: 0.20),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.cloud_off_rounded, color: PaykColors.bad, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: PaykColors.ink,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                minimumSize: const Size(160, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}
