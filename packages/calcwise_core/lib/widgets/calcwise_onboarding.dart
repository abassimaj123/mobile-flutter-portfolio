import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Persistence helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Returns true if onboarding has been completed for [appKey].
Future<bool> isOnboardingComplete(String appKey) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool('${appKey}_onboarding_complete') ?? false;
}

/// Marks onboarding as done for [appKey].
Future<void> markOnboardingComplete(String appKey) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('${appKey}_onboarding_complete', true);
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

/// Content for a single onboarding page with multi-locale support.
///
/// [title] / [subtitle] / [pills] / [bullets] are the EN defaults.
/// Provide [titleFr] / [subtitleFr] etc. to override for French devices.
/// Provide [titleEs] / [subtitleEs] etc. to override for Spanish devices.
/// [bulletIcons] maps 1-to-1 with [bullets] — specific icon per feature row.
class OnboardingPage {
  /// Hero icon shown in the top container. Branded over emoji for consistency.
  final IconData icon;

  // EN (default)
  final String title;
  final String subtitle;
  final List<String>? pills;
  final List<String>? bullets;

  // FR overrides
  final String? titleFr;
  final String? subtitleFr;
  final List<String>? pillsFr;
  final List<String>? bulletsFr;

  // ES overrides
  final String? titleEs;
  final String? subtitleEs;
  final List<String>? pillsEs;
  final List<String>? bulletsEs;

  /// Specific icon per bullet item (index-matched to [bullets]).
  /// If null or shorter than [bullets], falls back to check_circle_rounded.
  final List<IconData>? bulletIcons;

  /// Fully custom widget rendered below the subtitle (any locale).
  final Widget? customWidget;

  /// Tint for the hero container. Falls back to [ColorScheme.primary].
  final Color? containerColor;

  const OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.pills,
    this.bullets,
    this.titleFr,
    this.subtitleFr,
    this.pillsFr,
    this.bulletsFr,
    this.titleEs,
    this.subtitleEs,
    this.pillsEs,
    this.bulletsEs,
    this.bulletIcons,
    this.customWidget,
    this.containerColor,
  });

  /// Resolve title for the given language code.
  String resolvedTitle(String lang) {
    if (lang == 'fr' && titleFr != null) return titleFr!;
    if (lang == 'es' && titleEs != null) return titleEs!;
    return title;
  }

  /// Resolve subtitle for the given language code.
  String resolvedSubtitle(String lang) {
    if (lang == 'fr' && subtitleFr != null) return subtitleFr!;
    if (lang == 'es' && subtitleEs != null) return subtitleEs!;
    return subtitle;
  }

  /// Resolve pills for the given language code.
  List<String>? resolvedPills(String lang) {
    if (lang == 'fr' && pillsFr != null) return pillsFr;
    if (lang == 'es' && pillsEs != null) return pillsEs;
    return pills;
  }

  /// Resolve bullets for the given language code.
  List<String>? resolvedBullets(String lang) {
    if (lang == 'fr' && bulletsFr != null) return bulletsFr;
    if (lang == 'es' && bulletsEs != null) return bulletsEs;
    return bullets;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CalcwiseOnboarding widget
// ─────────────────────────────────────────────────────────────────────────────

class CalcwiseOnboarding extends StatefulWidget {
  final String appKey;
  final List<OnboardingPage> pages;
  final Widget? nextScreen;
  final VoidCallback? onDone;
  final bool showSkip;

  const CalcwiseOnboarding({
    super.key,
    required this.appKey,
    required this.pages,
    this.nextScreen,
    this.onDone,
    this.showSkip = true,
  }) : assert(nextScreen != null || onDone != null,
            'Provide either nextScreen or onDone');

  @override
  State<CalcwiseOnboarding> createState() => _CalcwiseOnboardingState();
}

class _CalcwiseOnboardingState extends State<CalcwiseOnboarding> {
  final _ctrl = PageController();
  int _page = 0;

  int get _last => widget.pages.length - 1;

  /// Device language code — resolved once after first frame.
  String _lang = 'en';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolve locale from Flutter's Localizations (set by MaterialApp).
    // Falls back to 'en' if not available.
    final locale = Localizations.maybeLocaleOf(context);
    if (locale != null) {
      _lang = locale.languageCode;
    }
  }

  void _next() {
    if (_page < _last) {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await markOnboardingComplete(widget.appKey);
    if (!mounted) return;
    if (widget.onDone != null) {
      widget.onDone!();
    } else {
      Navigator.of(context).pushReplacement(PageRouteBuilder<void>(
        pageBuilder:        (_, __, ___) => widget.nextScreen!,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration:        const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _getStartedLabel {
    if (_lang == 'fr') return 'Commencer';
    if (_lang == 'es') return 'Comenzar';
    return 'Get Started';
  }

  String get _nextLabel {
    if (_lang == 'fr') return 'Suivant';
    if (_lang == 'es') return 'Siguiente';
    return 'Next';
  }

  String get _skipLabel {
    if (_lang == 'fr') return 'Passer';
    if (_lang == 'es') return 'Omitir';
    return 'Skip';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLast = _page == _last;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(children: [
          // ── Top bar: dots + skip (always visible) ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.pages.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width:  _page == i ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _page == i ? cs.primary : cs.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const Spacer(),
              // Skip is always visible — including the last slide — so users
              // who don't want the full pitch can bail at any moment.
              if (widget.showSkip)
                TextButton(
                  onPressed: _finish,
                  child: Text(_skipLabel,
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500)),
                ),
            ]),
          ),

          // ── Pages ─────────────────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _ctrl,
              onPageChanged: (i) => setState(() => _page = i),
              children: widget.pages
                  .map((p) => _OnboardingPageView(page: p, lang: _lang))
                  .toList(),
            ),
          ),

          // ── Navigation: single full-width Next/Get Started button ────────
          // Back button removed — PageView swipe handles going back, and
          // dropping it gives the CTA more visual weight on every slide.
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  isLast ? _getStartedLabel : _nextLabel,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single page layout
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingPageView extends StatelessWidget {
  final OnboardingPage page;
  final String lang;
  const _OnboardingPageView({required this.page, required this.lang});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final containerColor = page.containerColor ?? cs.primary;
    final resolvedPills   = page.resolvedPills(lang);
    final resolvedBullets = page.resolvedBullets(lang);

    // Entrance animation: fade-in + slide-up keyed by page identity so it
    // replays whenever the user lands on a new slide.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Hero icon container
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: containerColor.withValues(alpha: 0.30),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                page.icon,
                size: 64,
                color: cs.onPrimary,
              ),
            ),
          ),

          const SizedBox(height: 36),

          // Animated block: title + subtitle + supporting content fade up
          // together on slide entry for a polished feel.
          TweenAnimationBuilder<double>(
            key: ValueKey(page.title),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
            builder: (context, t, child) {
              return Opacity(
                opacity: t,
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * 16),
                  child: child,
                ),
              );
            },
            child: Column(
              children: [
                // Title
                Text(
                  page.resolvedTitle(lang),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: 14),

                // Subtitle
                Text(
                  page.resolvedSubtitle(lang),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: cs.onSurfaceVariant,
                    height: 1.55,
                  ),
                ),

                const SizedBox(height: 28),

                // Pills
                if (resolvedPills != null && resolvedPills.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: resolvedPills
                        .map((p) => _FeaturePill(label: p))
                        .toList(),
                  ),

                // Premium bullets card
                if (resolvedBullets != null && resolvedBullets.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: cs.primary.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(resolvedBullets.length, (i) {
                        final icon = (page.bulletIcons != null &&
                                i < page.bulletIcons!.length)
                            ? page.bulletIcons![i]
                            : Icons.check_circle_rounded;
                        return Padding(
                          padding: EdgeInsets.only(
                              bottom:
                                  i < resolvedBullets.length - 1 ? 12 : 0),
                          child: _BulletRow(
                              label: resolvedBullets[i], icon: icon, cs: cs),
                        );
                      }),
                    ),
                  ),

                // Custom widget
                if (page.customWidget != null) page.customWidget!,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturePill extends StatelessWidget {
  final String label;
  const _FeaturePill({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        label,
        style: TextStyle(
            color: cs.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final ColorScheme cs;
  const _BulletRow({required this.label, required this.icon, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: cs.primary, size: 20),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: cs.onPrimaryContainer,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ]);
  }
}
