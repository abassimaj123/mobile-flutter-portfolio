import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/freemium_service.dart';
import '../services/ad_service.dart';
import '../theme/calcwise_theme.dart';

/// Universal monetization footer — drop-in for every Calcwise app screen.
///
/// Configure once in main() before runApp():
/// ```dart
/// CalcwiseAdFooter.configure(
///   adService:          adService,
///   freemium:           freemiumService,
///   isSpanishNotifier:  isSpanishNotifier, // optional
/// );
/// ```
/// Then use `const CalcwiseAdFooter()` in any screen — zero per-screen params.
///
/// Premium  → nothing (SizedBox.shrink)
/// Rewarded → green countdown timer only
/// Free     → "Watch ad" + "Get Premium" bar + banner ad
///
/// NOTE: all side-effects deferred to postFrameCallback to avoid the
/// Impeller/OpenGLES blank-layer bug when IndexedStack mounts screens
/// simultaneously.
class CalcwiseAdFooter extends StatefulWidget {
  const CalcwiseAdFooter({super.key});

  // ── Static configuration ────────────────────────────────────────────────

  static CalcwiseAdService?      _adService;
  static CalcwiseFreemium?       _freemium;
  static ValueNotifier<bool>?    _isSpanish;
  static VoidCallback?           _onGetPremium;

  static void configure({
    required CalcwiseAdService   adService,
    required CalcwiseFreemium    freemium,
    ValueNotifier<bool>?         isSpanishNotifier,
    VoidCallback?                onGetPremium,
  }) {
    _adService    = adService;
    _freemium     = freemium;
    _isSpanish    = isSpanishNotifier;
    _onGetPremium = onGetPremium;
  }

  @override
  State<CalcwiseAdFooter> createState() => _CalcwiseAdFooterState();
}

class _CalcwiseAdFooterState extends State<CalcwiseAdFooter> {
  BannerAd? _banner;
  bool _bannerLoaded  = false;
  bool _bannerRetried = false;
  bool _listenersAdded = false;
  bool _watchLoading  = false;
  Timer? _tick;

  static bool get _isConfigured =>
      CalcwiseAdFooter._adService != null && CalcwiseAdFooter._freemium != null;

  CalcwiseAdService  get _ad  => CalcwiseAdFooter._adService!;
  CalcwiseFreemium   get _fr  => CalcwiseAdFooter._freemium!;
  bool get _isEs => CalcwiseAdFooter._isSpanish?.value ?? false;

  @override
  void initState() {
    super.initState();
    if (!_isConfigured) return; // no-op in test environments
    WidgetsBinding.instance.addPostFrameCallback((_) => _setup());
  }

  void _setup() {
    if (!mounted) return;
    _listenersAdded = true;
    _fr.isPremiumNotifier.addListener(_rebuild);
    _fr.isRewardedNotifier.addListener(_rebuild);
    CalcwiseAdFooter._isSpanish?.addListener(_rebuild);
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    if (_fr.showAds) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _loadBanner();
      });
    }
  }

  @override
  void dispose() {
    if (_listenersAdded) {
      _fr.isPremiumNotifier.removeListener(_rebuild);
      _fr.isRewardedNotifier.removeListener(_rebuild);
      CalcwiseAdFooter._isSpanish?.removeListener(_rebuild);
    }
    _tick?.cancel();
    _banner?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
    if (_fr.showAds && _banner == null) _loadBanner();
  }

  void _loadBanner() {
    _banner = BannerAd(
      adUnitId: _ad.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() { _banner = ad as BannerAd; _bannerLoaded = true; });
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (!mounted) return;
          setState(() { _banner = null; _bannerLoaded = false; });
          if (!_bannerRetried) {
            _bannerRetried = true;
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) _loadBanner();
            });
          }
        },
      ),
    )..load();
  }

  Future<void> _watch() async {
    setState(() => _watchLoading = true);
    final earned = await _ad.showRewarded();
    if (earned) await _fr.activateRewarded();
    if (mounted) setState(() => _watchLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (CalcwiseAdFooter._adService == null || CalcwiseAdFooter._freemium == null) {
      return const SizedBox.shrink(); // not configured yet
    }

    // Premium — no ads, but still consume bottom inset to avoid nav-bar overflow
    if (_fr.isPremium) {
      return SizedBox(height: MediaQuery.of(context).padding.bottom);
    }

    final ct = CalcwiseTheme.of(context);

    // Rewarded active — countdown timer
    if (_fr.isRewarded) {
      final mins = _fr.rewardedRemaining?.inMinutes ?? 0;
      final label = _isEs
          ? 'Sin anuncios — $mins min restantes'
          : 'Ad-free — $mins min remaining';
      return SafeArea(
        top: false, left: false, right: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          color: ct.successGreen.withValues(alpha: 0.08),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.timer_rounded, size: 15, color: ct.successGreen),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
                color: ct.successGreen, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
    }

    // Free tier — watch ad + get premium + banner
    // Uses GestureDetector+Container (not Material buttons) to avoid the
    // Impeller/OpenGLES blank-layer bug when 5+ AdFooters mount simultaneously.
    return SafeArea(
      top: false, left: false, right: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          color: const Color(0xFFF8FAFC),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            // Watch ad button
            GestureDetector(
              onTap: (_watchLoading || !_fr.canWatchRewarded()) ? null : _watch,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _watchLoading
                      ? const SizedBox(width: 13, height: 13,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.play_circle_outline, size: 15, color: ct.primary),
                  const SizedBox(width: 4),
                  Text(
                    _watchLoading
                        ? (_isEs ? 'Cargando...' : 'Loading...')
                        : (_isEs ? 'Sin anuncios 60 min' : 'Ad-free for 60 min'),
                    style: TextStyle(fontSize: 11, color: ct.primary),
                  ),
                ]),
              ),
            ),
            const Spacer(),
            // Get Premium button
            GestureDetector(
              onTap: () => CalcwiseAdFooter._onGetPremium?.call(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: ct.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.workspace_premium, size: 14, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    _isEs ? 'Obtener Premium' : 'Get Premium',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 4),
          ]),
        ),
        if (_bannerLoaded && _banner != null)
          SizedBox(
            width: double.infinity,
            height: _banner!.size.height.toDouble(),
            child: AdWidget(ad: _banner!),
          ),
      ]),
    );
  }
}
