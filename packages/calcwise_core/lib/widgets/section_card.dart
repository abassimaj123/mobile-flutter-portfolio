import 'package:flutter/material.dart';
import '../theme/tokens/tokens.dart';

/// Groupe visuel standardisé — titre + contenu.
/// Usage: SectionCard(title: 'Vehicle', children: [...])
class SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final EdgeInsets? padding;

  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Ligne résultat standardisée — label + valeur.
/// Usage: ResultTile(label: 'Monthly Payment', value: '\$1,234.56')
class ResultTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;

  /// Optional semantic label override. Defaults to '$label: $value'.
  final String? semanticLabel;

  const ResultTile({
    super.key,
    required this.label,
    required this.value,
    this.isHighlight = false,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticLabel ?? '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isHighlight ? cs.primary : null,
                      fontWeight: isHighlight ? FontWeight.w700 : null,
                    ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isHighlight ? cs.primary : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
