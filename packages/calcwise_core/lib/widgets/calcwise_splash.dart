import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/calcwise_theme.dart';
import '../theme/tokens/motion_tokens.dart';

/// Plug-and-play animated splash screen.
///
/// Usage — replace your splash_screen.dart body:
/// ```dart
/// class SplashScreen extends StatelessWidget {
///   const SplashScreen({super.key});
///   @override
///   Widget build(BuildContext context) => CalcwiseSplash(
///     appName:   'Mortgage',
///     appSuffix: 'US',
///     tagline:   'Smart mortgage calculator',
///     chips:     ['2025 Rates', '51 States', 'Amortization'],
///     badgeSymbol: 'M\$',
///     onComplete: () => Navigator.pushReplacement(context,
///       MaterialPageRoute(builder: (_) => const HomeScreen())),
///   );
/// }
/// ```
class CalcwiseSplash extends StatefulWidget {
  final String appName;
  final String? appSuffix;       // shown in accent color after appName
  final String tagline;
  final List<String> chips;      // max 3 feature chips
  final String badgeSymbol;      // 1-2 chars shown in badge (fallback when no icon)
  final IconData? badgeIcon;     // when provided, shows a large icon instead of letters
  final VoidCallback onComplete;
  final int durationMs;
  /// Couleur de fond du splash animé.
  /// Passer la couleur primaire de l'app pour synchro icône → splash → app.
  /// Défaut : [Color(0xFF0D0B1E)] (rétrocompat).
  final Color backgroundColor;

  const CalcwiseSplash({
    super.key,
    required this.appName,
    this.appSuffix,
    required this.tagline,
    required this.chips,
    this.badgeSymbol = '',
    this.badgeIcon,
    required this.onComplete,
    this.durationMs = 1500,
    this.backgroundColor = const Color(0xFF0D0B1E),
  });

  @override
  State<CalcwiseSplash> createState() => _CalcwiseSplashState();
}

class _CalcwiseSplashState extends State<CalcwiseSplash>
    with TickerProviderStateMixin {

  late final AnimationController _bg;
  late final AnimationController _logo;
  late final AnimationController _content;

  late final Animation<double> _bgScale;
  late final Animation<double> _logoScale, _logoOpacity;
  late final Animation<double> _glowOpacity, _glowSize;
  late final Animation<Offset>  _nameSlide;
  late final Animation<double>  _nameOpacity, _tagOpacity, _chipsOpacity;

  bool _logoDone = false;
  // ignore: unused_field
  bool _contentDone = false;
  bool _exited = false;
  bool _canSkip = false;

  @override
  void initState() {
    super.initState();

    _bg = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 3000))..repeat(reverse: true);
    _bgScale = Tween<double>(begin: 1.0, end: 1.12)
        .animate(CurvedAnimation(parent: _bg, curve: Curves.easeInOut));

    _logo = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 900));
    _logoScale   = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logo, curve: const Interval(0.0, 0.75, curve: Curves.elasticOut)));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logo, curve: const Interval(0.0, 0.35, curve: Curves.easeOut)));
    _glowOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logo, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));
    _glowSize    = Tween<double>(begin: 80, end: 160).animate(
        CurvedAnimation(parent: _logo, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));

    _content = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 400));
    _nameSlide   = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _content,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutCubic)));
    _nameOpacity  = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _content, curve: const Interval(0.0, 0.45, curve: Curves.easeOut)));
    _tagOpacity   = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _content, curve: const Interval(0.25, 0.65, curve: Curves.easeOut)));
    _chipsOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _content, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));

    _logo.forward().then((_) {
      if (!mounted) return;
      _logoDone = true;
      _content.forward().then((_) {
        if (!mounted) return;
        _contentDone = true;
        // Stop the background glow loop once content has landed.
        _bg.stop();
      });
    });
    // Enable tap-to-skip once the brand frame has had time to land.
    Future.delayed(AppDuration.splashSkipThreshold, () {
      if (mounted) _canSkip = true;
    });
    Future.delayed(Duration(milliseconds: widget.durationMs), () {
      if (mounted) _exit();
    });
  }

  void _exit() {
    if (_exited) return;
    _exited = true;
    widget.onComplete();
  }

  void _trySkip() {
    // Allow tap-to-skip only after the skip threshold (~800ms) so the user
    // can't accidentally dismiss the brand frame the instant it appears.
    if (_canSkip || _logoDone) _exit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Splash — fond = couleur primaire de l'app (ou #0D0B1E par défaut)
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: widget.backgroundColor,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }

  @override
  void dispose() {
    _bg.dispose(); _logo.dispose(); _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ct = CalcwiseTheme.of(context);
    final splashBg = widget.backgroundColor;
    return Scaffold(
      backgroundColor: splashBg,
      body: GestureDetector(
        onTap: _trySkip,
        behavior: HitTestBehavior.opaque,
        child: Stack(children: [
        // Background glow blob
        Positioned.fill(child: AnimatedBuilder(
          animation: _bg,
          builder: (ctx, __) {
            final size = MediaQuery.of(ctx).size.height * 0.55;
            return Center(child: Transform.scale(
              scale: _bgScale.value,
              child: Container(width: size, height: size,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    ct.primaryDeep.withValues(alpha: 0.28),
                    ct.primaryDeep.withValues(alpha: 0.10),
                    Colors.transparent,
                  ])),
              ),
            ));
          },
        )),

        // Content
        SafeArea(child: Column(children: [
          const Flexible(flex: 5, child: SizedBox()),

          // Badge
          AnimatedBuilder(animation: _logo, builder: (_, __) =>
            Opacity(opacity: _logoOpacity.value,
              child: Transform.scale(scale: _logoScale.value,
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

          const Flexible(flex: 2, child: SizedBox()),

          // App name
          AnimatedBuilder(animation: _content, builder: (_, __) =>
            SlideTransition(position: _nameSlide,
              child: Opacity(opacity: _nameOpacity.value,
                child: RichText(text: TextSpan(children: [
                  TextSpan(text: widget.appName,
                    style: const TextStyle(color: Colors.white, fontSize: 38,
                        fontWeight: FontWeight.w800, letterSpacing: -1.2)),
                  if (widget.appSuffix != null)
                    TextSpan(text: ' ${widget.appSuffix}',
                      style: TextStyle(color: ct.accent, fontSize: 38,
                          fontWeight: FontWeight.w800, letterSpacing: -1.2)),
                ])),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Tagline
          AnimatedBuilder(animation: _content, builder: (_, __) =>
            Opacity(opacity: _tagOpacity.value,
              child: Text(widget.tagline,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 15, letterSpacing: 0.2)),
            ),
          ),

          const SizedBox(height: 20),

          // Feature chips
          AnimatedBuilder(animation: _content, builder: (_, __) =>
            Opacity(opacity: _chipsOpacity.value,
              child: Wrap(
                spacing: 8, runSpacing: 6,
                alignment: WrapAlignment.center,
                children: widget.chips.map((c) => _Chip(c)).toList(),
              ),
            ),
          ),

          const Spacer(),
          const SizedBox(height: 28),
        ])),
      ]),
      ),
    );
  }
}

// ── Badge ────────────────────────────────────────────────────────────────────

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

  // Fallback: use only the first character — single, flat letter (no stacking).
  String get _letter => badgeSymbol.isNotEmpty ? badgeSymbol[0] : '?';

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      // Glow halo
      Opacity(opacity: glowOpacity,
        child: Container(width: glowSize * 2, height: glowSize * 2,
          decoration: BoxDecoration(shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              ct.primaryDeep.withValues(alpha: 0.50),
              ct.primaryDeep.withValues(alpha: 0.20),
              Colors.transparent,
            ])),
        ),
      ),
      // Badge card
      Container(
        width: 140, height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ct.primaryDeep, ct.primary.withValues(alpha: 0.7)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: Colors.white.withValues(alpha: 0.38), width: 2),
          boxShadow: [BoxShadow(
            color: ct.primaryDeep.withValues(alpha: 0.55),
            blurRadius: 40, offset: const Offset(0, 12),
          )],
        ),
        child: Center(
          child: badgeIcon != null
              ? Icon(badgeIcon, color: Colors.white, size: 72)
              : Text(_letter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                  )),
        ),
      ),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
    ),
    child: Text(text, style: TextStyle(
        color: Colors.white.withValues(alpha: 0.85), fontSize: 13,
        fontWeight: FontWeight.w500)),
  );
}
