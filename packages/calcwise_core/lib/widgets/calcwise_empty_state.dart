import 'package:flutter/material.dart';
import '../theme/calcwise_theme.dart';
import '../theme/tokens/tokens.dart';

/// Shared empty-state widget for all Calcwise portfolio apps.
///
/// Shows an icon, title, optional body text, and an optional CTA button.
///
/// Usage:
/// ```dart
/// CalcwiseEmptyState(
///   icon: Icons.history_rounded,
///   title: 'No history yet',
///   body: 'Your saved calculations will appear here.',
///   actionLabel: 'Calculate now',
///   onAction: () => _navigateToCalculator(),
/// )
/// ```
class CalcwiseEmptyState extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String?  body;
  final String?  actionLabel;
  final VoidCallback? onAction;

  /// Overrides the icon container color. Defaults to primary with 10% opacity.
  final Color? iconColor;

  const CalcwiseEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final ct      = CalcwiseTheme.of(context);
    final primary = Theme.of(context).colorScheme.primary;

    return Semantics(
      label: body != null ? '$title. $body' : title,
      child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl, vertical: AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (iconColor ?? primary).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: iconColor ?? primary),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              style: TextStyle(
                fontSize: AppTextSize.bodyXl,
                fontWeight: FontWeight.w600,
                color: ct.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                body!,
                style: TextStyle(
                  fontSize: AppTextSize.md,
                  color: ct.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
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
