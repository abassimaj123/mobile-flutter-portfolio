import 'package:flutter/material.dart';
import '../theme/calcwise_theme.dart';
import '../theme/tokens/tokens.dart';

/// Standard error state widget for all Calcwise portfolio apps.
///
/// Shows an error icon, a user-friendly message, and an optional retry button.
///
/// Usage:
/// ```dart
/// CalcwiseErrorState(
///   message: 'Could not load history.',
///   onRetry: _loadHistory,
/// )
/// ```
class CalcwiseErrorState extends StatelessWidget {
  /// Short user-facing message. Keep it non-technical.
  final String message;

  /// Optional retry callback. Renders a "Try again" button when set.
  final VoidCallback? onRetry;

  /// Optional icon. Defaults to [Icons.error_outline_rounded].
  final IconData? icon;

  const CalcwiseErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ct    = CalcwiseTheme.of(context);
    final error = Theme.of(context).colorScheme.error;

    return Semantics(
      label: 'Error: $message',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xxxl, vertical: AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon ?? Icons.error_outline_rounded,
                  size: 34,
                  color: error,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                message,
                style: TextStyle(
                  fontSize: AppTextSize.bodyXl,
                  fontWeight: FontWeight.w600,
                  color: ct.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.xxl),
                SizedBox(
                  width: 160,
                  child: OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Try again'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
