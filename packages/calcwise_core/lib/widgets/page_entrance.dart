import 'dart:async';
import 'package:flutter/material.dart';

/// Wraps a widget with a one-shot fade-in + slide-up entrance animation.
///
/// Usage — wrap the Scaffold body (or an individual section):
/// ```dart
/// body: CalcwisePageEntrance(child: _buildBody()),
/// ```
///
/// For staggered children use [CalcwiseStaggerItem] inside a Column:
/// ```dart
/// Column(children: [
///   CalcwiseStaggerItem(index: 0, child: HeroBanner()),
///   CalcwiseStaggerItem(index: 1, child: InputCard()),
///   CalcwiseStaggerItem(index: 2, child: ResultCard()),
/// ])
/// ```
class CalcwisePageEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final double slideOffset;

  const CalcwisePageEntrance({
    super.key,
    required this.child,
    this.duration  = const Duration(milliseconds: 480),
    this.delay     = const Duration(milliseconds: 80),
    this.slideOffset = 32.0,
  });

  @override
  State<CalcwisePageEntrance> createState() => _CalcwisePageEntranceState();
}

class _CalcwisePageEntranceState extends State<CalcwisePageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _opacity;
  late final Animation<Offset>   _slide;
  bool   _started = false;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide   = Tween<Offset>(
      begin: Offset(0, widget.slideOffset / 200),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  void _maybeStart() {
    if (_started || !mounted) return;
    _started = true;
    _delayTimer = Timer(widget.delay, () {
      if (!mounted) return;
      _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _opacity,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

/// Individual staggered item — use inside a Column wrapped by [CalcwisePageEntrance].
/// Each [index] fires [index * staggerMs] ms after mount.
class CalcwiseStaggerItem extends StatefulWidget {
  final int index;
  final Widget child;
  final int staggerMs;
  final int baseDelayMs;

  const CalcwiseStaggerItem({
    super.key,
    required this.index,
    required this.child,
    this.staggerMs   = 70,
    this.baseDelayMs = 100,
  });

  @override
  State<CalcwiseStaggerItem> createState() => _CalcwiseStaggerItemState();
}

class _CalcwiseStaggerItemState extends State<CalcwiseStaggerItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset>   _slide;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    // Slide animation only (no opacity fade-in — avoids blank on cold mount)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final delay = widget.baseDelayMs + widget.index * widget.staggerMs;
      _delayTimer = Timer(Duration(milliseconds: delay), () {
        if (!mounted) return;
        _ctrl.forward();
      });
    });
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _slide, child: widget.child);
  }
}
