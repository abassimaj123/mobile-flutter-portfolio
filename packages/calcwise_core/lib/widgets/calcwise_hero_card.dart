import 'package:flutter/material.dart';
import '../theme/tokens/tokens.dart';

/// Unified hero result card for calculator screens.
/// Pattern: full-bleed bottom-rounded, white-on-primary, 52px hero number.
class CalcwiseHeroCard extends StatelessWidget {
  final String label;          // e.g. "Monthly Payment" — uppercase 11px
  final String value;          // e.g. "\$2,540" — 52px hero
  final String? secondary;     // optional subtext, e.g. "P&I only"
  final List<Widget>? badges;  // optional row of chips (LTV, PMI, term)
  final List<({String label, String value})>? stats;  // optional bottom stats row
  final Color? backgroundColor; // defaults to colorScheme.primary
  final Gradient? gradient;    // overrides backgroundColor when set

  const CalcwiseHeroCard({
    super.key,
    required this.label,
    required this.value,
    this.secondary,
    this.badges,
    this.stats,
    this.backgroundColor,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      decoration: BoxDecoration(
        color: gradient == null ? bg : null,
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: AppTextSize.xs,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: Text(
              value,
              key: ValueKey(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 52,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
                height: 1.0,
              ),
            ),
          ),
          if (secondary != null) ...[
            const SizedBox(height: 4),
            Text(
              secondary!,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
          if (badges != null && badges!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: badges!),
          ],
          if (stats != null && stats!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: stats!.map((s) => Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.label.toUpperCase(),
                      style: const TextStyle(color: Colors.white70, fontSize: AppTextSize.xs, fontWeight: FontWeight.w600, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.value,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pill badge for use inside CalcwiseHeroCard.badges
class CalcwiseHeroBadge extends StatelessWidget {
  final String label;
  final IconData? icon;
  const CalcwiseHeroBadge({super.key, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
          ],
          Text(label, style: const TextStyle(color: Colors.white, fontSize: AppTextSize.xs, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
