import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/models/parking_session.dart';

class SessionAlertBanner extends StatelessWidget {
  final ParkingSession session;
  final VoidCallback onDismiss;
  final VoidCallback onEnd;

  const SessionAlertBanner({
    super.key,
    required this.session,
    required this.onDismiss,
    required this.onEnd,
  });

  Color get _bgColor {
    if (session.isOverLimit) return const Color(0xFFB71C1C);
    if (session.isUrgent) return CalcwiseSemanticColors.errorDark;
    if (session.isNearingLimit) return const Color(0xFFE65100);
    return const Color(0xFF1A237E);
  }

  String get _message {
    final rem = session.minutesRemaining;
    if (session.isOverLimit) {
      return 'Limite dépassée ! Déplacez votre véhicule';
    }
    if (rem != null) {
      if (rem <= 10) {
        return 'Urgent — encore $rem min avant la limite';
      }
      if (rem <= 30) {
        return 'Zone max ${_formatMins(session.maxMinutes!)} — encore $rem min';
      }
      return 'Session active — $rem min restantes';
    }
    return 'Session de stationnement active';
  }

  String _formatMins(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    return '${h}h';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDuration.page,
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: _bgColor.withAlpha(102),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: onEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.mdPlus, vertical: AppSpacing.smPlus),
            child: Row(
              children: [
                // Animated car icon
                _PulsingIcon(isUrgent: session.isUrgent || session.isOverLimit),
                const SizedBox(width: AppSpacing.smPlus),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        session.segment.streetName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: AppTextSize.md,
                        ),
                      ),
                      Text(
                        _message,
                        style: TextStyle(
                          color: Colors.white.withAlpha(230),
                          fontSize: AppTextSize.sm,
                        ),
                      ),
                    ],
                  ),
                ),
                // Elapsed time
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatElapsed(session.elapsed),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: AppTextSize.bodyLg,
                      ),
                    ),
                    Text(
                      'écoulé',
                      style: TextStyle(
                        color: Colors.white.withAlpha(179),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: onDismiss,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 18,
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

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}';
    return '${m}min';
  }
}

class _PulsingIcon extends StatefulWidget {
  final bool isUrgent;

  const _PulsingIcon({required this.isUrgent});

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (widget.isUrgent) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_PulsingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isUrgent && !oldWidget.isUrgent) {
      _controller.repeat(reverse: true);
      HapticFeedback.heavyImpact();
    } else if (!widget.isUrgent && oldWidget.isUrgent) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    return ScaleTransition(
      scale: (widget.isUrgent && !disableAnimations)
          ? _animation
          : const AlwaysStoppedAnimation(1.0),
      child: const Icon(
        Icons.directions_car,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}
