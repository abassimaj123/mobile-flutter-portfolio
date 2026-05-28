import 'package:flutter/material.dart';
import '../theme/tokens/tokens.dart';

/// Shimmer skeleton loading widget for all Calcwise portfolio apps.
///
/// Renders animated placeholder rows that mirror a typical results screen.
/// Drop this in place of your real content while async work is in progress.
///
/// Usage:
/// ```dart
/// if (_isLoading)
///   const CalcwiseLoadingState()
/// else
///   MyResultWidget(...)
/// ```
///
/// For custom layouts use [CalcwiseSkeleton] directly:
/// ```dart
/// CalcwiseSkeleton.line(width: 120)
/// CalcwiseSkeleton.box(height: 80)
/// ```
class CalcwiseLoadingState extends StatelessWidget {
  /// Number of result-row skeletons to show (default 4).
  final int rowCount;

  /// Whether to show a hero-card placeholder at the top.
  final bool showHeroCard;

  const CalcwiseLoadingState({
    super.key,
    this.rowCount = 4,
    this.showHeroCard = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading results',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeroCard) ...[
                _ShimmerBox(height: 120, borderRadius: AppRadius.xl),
                const SizedBox(height: AppSpacing.xxl),
              ],
              // Section title placeholder
              _ShimmerBox(width: 140, height: 14, borderRadius: AppRadius.xs),
              const SizedBox(height: AppSpacing.lg),
              // Result rows
              for (int i = 0; i < rowCount; i++) ...[
                _ResultRowSkeleton(widthFraction: i.isEven ? 0.6 : 0.45),
                if (i < rowCount - 1)
                  const Divider(height: AppSpacing.xl, indent: 0, endIndent: 0),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Single animated shimmer row placeholder (label + value).
class _ResultRowSkeleton extends StatelessWidget {
  final double widthFraction;
  const _ResultRowSkeleton({required this.widthFraction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ShimmerBox(
          width: MediaQuery.sizeOf(context).width * widthFraction,
          height: 14,
          borderRadius: AppRadius.xs,
        ),
        _ShimmerBox(width: 72, height: 14, borderRadius: AppRadius.xs),
      ],
    );
  }
}

/// Animating shimmer placeholder box.
class _ShimmerBox extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;

  const _ShimmerBox({
    this.width,
    required this.height,
    this.borderRadius = AppRadius.sm,
  });

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base  = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8);
    final shine = isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(base, shine, _anim.value),
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

/// Public shimmer primitive for custom layouts.
class CalcwiseSkeleton {
  CalcwiseSkeleton._();

  /// A single skeleton line of given [width] and [height].
  static Widget line({double? width, double height = 14}) =>
      _ShimmerBox(width: width, height: height, borderRadius: AppRadius.xs);

  /// A skeleton box (card placeholder) of given [height].
  static Widget box({double height = 80, double? width}) =>
      _ShimmerBox(width: width, height: height, borderRadius: AppRadius.lg);
}
