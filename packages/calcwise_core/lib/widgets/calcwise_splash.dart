import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/calcwise_theme.dart';

/// Plug-and-play animated splash screen with 3-dot intro sequence.
///
/// Animation timeline:
///   Phase 1 (0–500ms)   : 3 dots appear staggered + pulse
///   Phase 2 (500–900ms) : dots spread apart & fade, badge scales in
///   Phase 3 (900–1300ms): app name slides up, tagline + chips fade in
///
/// Usage:
/// ```dart
/// CalcwiseSplash(
///   appName:   'Mortgage',
///   appSuffix: 'US',
///   tagline:   'Smart mortgage calculator',
///   chips:     ['2025 Rates', '51 States', 'Amortization'],
///   badgeIcon: Icons.home_work_rounded,
///   backgroundColor: AppTheme.primary,
///   onComplete: () => Navigator.pushReplacement(...),
/// )
/// ```
class CalcwiseSplash extends StatefulWidget {
  final String appName;
  final String? appSuffix;
  final String tagline;
  final List<String> chips;
  final String badgeSymbol;
  final IconData? badgeIcon;
  final VoidCallback onComplete;
  final int durationMs;
  final Color backgroundColor;
  /// Set to false when the native Android splash already shows the 3-dot
  /// animation (animated_splash_dots). Skips CalcwiseSplash's own dot intro
  /// and jumps straight to the badge + content reveal.
  final bool showDotsIntro;

  const CalcwiseSplash({
    super.key,
    required this.appName,
    this.appSuffix,
    required this.tagline,
    required this.chips,
    this.badgeSymbol = '',
    this.badgeIcon,
    required this.onComplete,
    this.durationMs = 3000,
    this.backgroundColor = const Color(0xFF0D0B1E),
    this.showDotsIntro = true,
  });

  @override
  State<CalcwiseSplash> createState() => _CalcwiseSplashState();
}

class _CalcwiseSplashState extends State<CalcwiseSplash>
    with TickerProviderStateMixin {

  // ── Controllers ─────────────────────────────────────────────────────────────
  late final AnimationController _bgCtrl;   // ambient glow pulse (loops)
  late final AnimationController _dotsCtrl; // dots intro phase (1000ms)
  late final AnimationController _logoCtrl; // badge entry (700ms)
  late final AnimationController _contentCtrl; // text + chips (500ms)

  // ── Background glow ─────────────────────────────────────────────────────────
  late final Animation<double> _bgScale;

  // ── Dots ────────────────────────────────────────────────────────────────────
  // Each dot: opacity + scale, staggered by 0 / 150 / 300 ms
  late final Animation<double> _d1Opacity, _d2Opacity, _d3Opacity;
  late final Animation<double> _d1Scale,   _d2Scale,   _d3Scale;
  // Horizontal spread on exit
  late final Animation<double> _d1X, _d3X;
  // Group fade-out
  late final Animation<double> _dotsGroupOpacity;

  // ── Badge ───────────────────────────────────────────────────────────────────
  late final Animation<double> _badgeScale, _badgeOpacity, _glowOpacity, _glowSize;

  // ── Content ─────────────────────────────────────────────────────────────────
  late final Animation<Offset>  _nameSlide;
  late final Animation<double>  _nameOpacity, _tagOpacity, _chipsOpacity;

  bool _exited   = false;
  bool _canSkip  = false;

  // ── Dot size + gap ──────────────────────────────────────────────────────────
  static const double _dotR1  = 5.0;   // small dot radius
  static const double _dotR2  = 7.0;   // medium dot radius
  static const double _dotR3  = 8.0;   // large dot radius
  static const double _dotGap = 22.0;  // center-to-center

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _runSequence();
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _canSkip = true);
    });
    Future<void>.delayed(Duration(milliseconds: widget.durationMs), () {
      if (mounted) _exit();
    });
  }

  void _setupAnimations() {
    // ── Background glow (loops) ──────────────────────────────────────────────
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3200))
      ..repeat(reverse: true);
    _bgScale = Tween<double>(begin: 1.0, end: 1.14)
        .animate(CurvedAnimation(parent: _bgCtrl, curve: Curves.easeInOut));

    // ── Dots (1000ms) ────────────────────────────────────────────────────────
    // Timeline inside [0.0 … 1.0]:
    //  0.00–0.22  dot1 appears        (220ms)
    //  0.08–0.30  dot2 appears        (220ms, +80ms delay)
    //  0.16–0.38  dot3 appears        (220ms, +160ms delay)
    //  0.00–0.65  pulse scale (all)
    //  0.55–0.85  dots spread sideways
    //  0.65–1.00  dots + badge group fade
    _dotsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));

    // Dots are immediately visible at full opacity — no fade-in delay
    // so when Flutter takes over from native splash, name + dots appear together
    _d1Opacity = _intervalTween(0.00, 1.00, 1.0, 1.0, _dotsCtrl);
    _d2Opacity = _intervalTween(0.00, 1.00, 1.0, 1.0, _dotsCtrl);
    _d3Opacity = _intervalTween(0.00, 1.00, 1.0, 1.0, _dotsCtrl);

    // Scale: start stable → pulse up → shrink on exit
    _d1Scale = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 35),
      // pulse up
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.18)
          .chain(CurveTween(curve: Curves.easeInOut)), weight: 12),
      TweenSequenceItem(tween: Tween(begin: 1.18, end: 1.0)
          .chain(CurveTween(curve: Curves.easeInOut)), weight: 10),
      // hold
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 8),
      // exit shrink
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0)
          .chain(CurveTween(curve: Curves.easeIn)), weight: 35),
    ]).animate(_dotsCtrl);

    // dot2 + dot3 same shape — slight offset handled by opacity stagger
    _d2Scale = _d1Scale;
    _d3Scale = _d1Scale;

    // Horizontal spread on exit: dot1 goes left, dot3 goes right
    _d1X = _intervalTween(0.55, 0.90, 0.0, -_dotGap * 0.6, _dotsCtrl,
        curve: Curves.easeInCubic);
    _d3X = _intervalTween(0.55, 0.90, 0.0,  _dotGap * 0.6, _dotsCtrl,
        curve: Curves.easeInCubic);

    _dotsGroupOpacity =
        _intervalTween(0.65, 1.00, 1.0, 0.0, _dotsCtrl, curve: Curves.easeIn);

    // ── Badge entry (700ms) ──────────────────────────────────────────────────
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _badgeScale   = CurvedAnimation(parent: _logoCtrl,
        curve: const Interval(0.0, 0.70, curve: Curves.easeOutBack));
    _badgeOpacity = _intervalTween(0.0, 0.35, 0.0, 1.0, _logoCtrl);
    _glowOpacity  = _intervalTween(0.3, 1.0,  0.0, 1.0, _logoCtrl);
    _glowSize     = Tween<double>(begin: 80, end: 160).animate(
        CurvedAnimation(parent: _logoCtrl,
            curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));

    // ── Content (500ms) ──────────────────────────────────────────────────────
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _nameSlide   = Tween<Offset>(
        begin: const Offset(0, 0.15), end: Offset.zero).animate(
        CurvedAnimation(parent: _contentCtrl,
            curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic)));
    _nameOpacity  = _intervalTween(0.0, 0.45, 0.0, 1.0, _contentCtrl);
    _tagOpacity   = _intervalTween(0.25, 0.65, 0.0, 1.0, _contentCtrl);
    _chipsOpacity = _intervalTween(0.50, 1.0,  0.0, 1.0, _contentCtrl);
  }

  Future<void> _runSequence() async {
    if (widget.showDotsIntro) {
      // Phase 1: dots intro
      await _dotsCtrl.forward();
      if (!mounted) return;
    } else {
      // Skip dots: content visible immediately, just animate badge
      _contentCtrl.value = 1.0;
    }

    // Badge + chips
    _logoCtrl.forward();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    if (widget.showDotsIntro) await _contentCtrl.forward();
    if (!mounted) return;
    _bgCtrl.stop();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Animation<double> _intervalTween(
    double begin, double end,
    double from, double to,
    AnimationController ctrl, {
    Curve curve = Curves.easeOut,
  }) =>
      Tween<double>(begin: from, end: to).animate(
        CurvedAnimation(parent: ctrl, curve: Interval(begin, end, curve: curve)),
      );

  void _exit() {
    if (_exited) return;
    _exited = true;
    widget.onComplete();
  }

  void _trySkip() {
    if (_canSkip) _exit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: widget.backgroundColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _dotsCtrl.dispose();
    _logoCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: GestureDetector(
        onTap: _trySkip,
        behavior: HitTestBehavior.opaque,
        child: Stack(children: [

          // ── Ambient glow ─────────────────────────────────────────────────
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgCtrl,
              builder: (ctx, __) {
                final sz = MediaQuery.of(ctx).size.height * 0.55;
                return Center(
                  child: Transform.scale(
                    scale: _bgScale.value,
                    child: Container(
                      width: sz, height: sz,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          ct.primaryDeep.withValues(alpha: 0.28),
                          ct.primaryDeep.withValues(alpha: 0.10),
                          Colors.transparent,
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Dots (bottom — Facebook style) ───────────────────────────────
          Positioned(
            bottom: 80, left: 0, right: 0,
            child: AnimatedBuilder(
              animation: _dotsCtrl,
              builder: (_, __) => Opacity(
                opacity: _dotsGroupOpacity.value.clamp(0.0, 1.0),
                child: Center(
                  child: SizedBox(
                    height: _dotR3 * 2,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDot(
                          opacity: _d1Opacity.value,
                          scale:   _d1Scale.value,
                          dx:      _d1X.value,
                          color:   Colors.white,
                          radius:  _dotR1,
                        ),
                        const SizedBox(width: _dotGap - _dotR1 - _dotR2),
                        _buildDot(
                          opacity: _d2Opacity.value,
                          scale:   _d2Scale.value,
                          dx:      0,
                          color:   Colors.white,
                          radius:  _dotR2,
                        ),
                        const SizedBox(width: _dotGap - _dotR2 - _dotR3),
                        _buildDot(
                          opacity: _d3Opacity.value,
                          scale:   _d3Scale.value,
                          dx:      _d3X.value,
                          color:   Colors.white,
                          radius:  _dotR3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Main content ─────────────────────────────────────────────────
          SafeArea(
            child: Column(children: [
              const SizedBox(height: 44),

              // App name — static, always visible at top
              RichText(
                text: TextSpan(children: [
                  TextSpan(
                    text: widget.appName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                    ),
                  ),
                  if (widget.appSuffix != null)
                    TextSpan(
                      text: ' ${widget.appSuffix}',
                      style: TextStyle(
                        color: ct.accent,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.2,
                      ),
                    ),
                ]),
              ),

              const SizedBox(height: 6),

              // Tagline — static
              Text(
                widget.tagline,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),

              const Spacer(),

              // Badge (animated)
              AnimatedBuilder(
                animation: _logoCtrl,
                builder: (_, __) => Transform.scale(
                  scale: _badgeScale.value,
                  child: Opacity(
                    opacity: _badgeOpacity.value.clamp(0.0, 1.0),
                    child: _Badge(
                      badgeSymbol: widget.badgeSymbol,
                      badgeIcon:   widget.badgeIcon,
                      ct:          ct,
                      glowOpacity: _glowOpacity.value,
                      glowSize:    _glowSize.value,
                    ),
                  ),
                ),
              ),

              const Spacer(),

              // Feature chips (animated)
              AnimatedBuilder(
                animation: _contentCtrl,
                builder: (_, __) => Opacity(
                  opacity: _chipsOpacity.value,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children:
                        widget.chips.map((c) => _Chip(c, ct)).toList(),
                  ),
                ),
              ),

              const SizedBox(height: 120),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildDot({
    required double opacity,
    required double scale,
    required double dx,
    required Color color,
    double radius = _dotR2,
  }) =>
      Transform.translate(
        offset: Offset(dx, 0),
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale.clamp(0.0, 2.0),
            child: Container(
              width:  radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ── Badge ─────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String badgeSymbol;
  final IconData? badgeIcon;
  final CalcwiseTheme ct;
  final double glowOpacity, glowSize;

  const _Badge({
    required this.badgeSymbol,
    this.badgeIcon,
    required this.ct,
    required this.glowOpacity,
    required this.glowSize,
  });

  String get _letter => badgeSymbol.isNotEmpty ? badgeSymbol[0] : '?';

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      // Glow halo
      Opacity(
        opacity: glowOpacity.clamp(0.0, 1.0),
        child: Container(
          width: glowSize * 2, height: glowSize * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              ct.primaryDeep.withValues(alpha: 0.50),
              ct.primaryDeep.withValues(alpha: 0.20),
              Colors.transparent,
            ]),
          ),
        ),
      ),
      // Badge card
      Container(
        width: 140, height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ct.primaryDeep, ct.primary.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.38),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: ct.primaryDeep.withValues(alpha: 0.55),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Center(
          child: badgeIcon != null
              ? Icon(badgeIcon, color: Colors.white, size: 72)
              : Text(
                  _letter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  ),
                ),
        ),
      ),
    ]);
  }
}

// ── Chip ──────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String text;
  final CalcwiseTheme ct;
  const _Chip(this.text, this.ct);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.85),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}
