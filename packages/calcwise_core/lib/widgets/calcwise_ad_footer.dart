import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/freemium_service.dart';
import '../services/ad_service.dart';
import '../theme/calcwise_theme.dart';
import '../theme/tokens/tokens.dart';
import 'calcwise_reward_ad_sheet.dart';
import 'paywall_hard.dart';

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
  static ValueNotifier<bool>?    _isFrench;
  static VoidCallback?           _onGetPremium;

  static void configure({
    required CalcwiseAdService   adService,
    required CalcwiseFreemium    freemium,
    ValueNotifier<bool>?         isSpanishNotifier,
    ValueNotifier<bool>?         isFrenchNotifier,
    VoidCallback?                onGetPremium,
  }) {
    _adService    = adService;
    _freemium     = freemium;
    _isSpanish    = isSpanishNotifier;
    _isFrench     = isFrenchNotifier;
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
  bool get _isFr => CalcwiseAdFooter._isFrench?.value ?? false;
  bool get _isEs => !_isFr && (CalcwiseAdFooter._isSpanish?.value ?? false);

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
    CalcwiseAdFooter._isFrench?.addListener(_rebuild);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
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
      CalcwiseAdFooter._isFrench?.removeListener(_rebuild);
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

    // Rewarded active — tappable countdown timer (opens sheet to show details)
    if (_fr.isRewarded) {
      final remaining = _fr.rewardedRemaining;
      final mins = remaining?.inMinutes ?? 0;
      final secs = (remaining?.inSeconds.remainder(60)) ?? 0;
      final timeStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
      final label = _isFr
          ? 'Sans pub — $timeStr restantes'
          : (_isEs
              ? 'Sin anuncios — $timeStr restantes'
              : 'Ad-free — $timeStr remaining');
      return SafeArea(
        top: false, left: false, right: false,
        child: GestureDetector(
          onTap: () => CalcwiseRewardAdSheet.show(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: ct.successGreen.withValues(alpha: 0.08),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.shield_rounded, size: 15, color: ct.successGreen),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(
                  color: ct.successGreen, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 14, color: ct.successGreen),
            ]),
          ),
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
                        ? (_isFr ? 'Chargement...' : (_isEs ? 'Cargando...' : 'Loading...'))
                        : (_isFr ? 'Sans pub 60 min' : (_isEs ? 'Sin anuncios 60 min' : 'Ad-free for 60 min')),
                    style: TextStyle(fontSize: AppTextSize.xs, color: ct.primary),
                  ),
                ]),
              ),
            ),
            const Spacer(),
            // Get Premium button — falls back to PaywallHard if no custom callback
            GestureDetector(
              onTap: () => CalcwiseAdFooter._onGetPremium != null
                  ? CalcwiseAdFooter._onGetPremium!()
                  : PaywallHard.show(context),
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
                    _isFr ? 'Passer Premium' : (_isEs ? 'Obtener Premium' : 'Get Premium'),
                    style: const TextStyle(
                        fontSize: AppTextSize.xs, fontWeight: FontWeight.bold, color: Colors.white),
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
