import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../main.dart' show adService;
import '../theme/app_theme.dart';
import '../freemium/freemium_service.dart';
import '../freemium/iap_service.dart';
import '../language/language_notifier.dart';
import 'package:calcwise_core/calcwise_core.dart';

/// Universal monetization footer — replaces banner-only widget.
///
/// Premium  → nothing rendered
/// Rewarded → green ad-free timer only (no banner)
/// Free     → "Watch ad" button + "Get Premium" button + banner ad
class AdFooter extends StatefulWidget {
  const AdFooter({super.key});
  @override
  State<AdFooter> createState() => _AdFooterState();
}

class _AdFooterState extends State<AdFooter> {
  BannerAd? _banner;
  bool _bannerLoaded = false;
  bool _bannerRetried = false;
  bool _listenersAdded = false;
  bool _watchLoading = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupAfterFrame());
  }

  void _setupAfterFrame() {
    if (!mounted) return;
    _listenersAdded = true;
    freemiumService.isPremiumNotifier.addListener(_rebuild);
    freemiumService.isRewardedNotifier.addListener(_rebuild);
    isSpanishNotifier.addListener(_rebuild);
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    if (freemiumService.showAds) {
      Future.delayed(AppDuration.page, () {
        if (mounted) _loadBanner();
      });
    }
  }

  @override
  void dispose() {
    if (_listenersAdded) {
      freemiumService.isPremiumNotifier.removeListener(_rebuild);
      freemiumService.isRewardedNotifier.removeListener(_rebuild);
      isSpanishNotifier.removeListener(_rebuild);
    }
    _tick?.cancel();
    _banner?.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
    if (freemiumService.showAds && _banner == null) _loadBanner();
  }

  void _loadBanner() {
    _banner = BannerAd(
      adUnitId: adService.bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted)
            setState(() {
              _banner = ad as BannerAd;
              _bannerLoaded = true;
            });
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _banner = null;
            _bannerLoaded = false;
          });
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
    if (_watchLoading) return;
    setState(() => _watchLoading = true);
    final earned = await adService.showRewarded();
    if (earned) await freemiumService.activateRewarded();
    if (mounted) setState(() => _watchLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (freemiumService.isPremium) return const SizedBox.shrink();

    final isEs = isSpanishNotifier.value;

    // ── Rewarded active: timer banner only ──────────────────────────────────
    if (freemiumService.isRewarded) {
      final mins = freemiumService.rewardedRemaining?.inMinutes ?? 0;
      final label = isEs
          ? 'Sin anuncios — $mins min restantes'
          : 'Ad-free — $mins min remaining';
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        color: AppTheme.accentGood.withValues(alpha: 0.08),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.timer_rounded, size: 15, color: AppTheme.accentGood),
          const SizedBox(width: AppSpacing.xs),
          Text(label,
              style: TextStyle(
                  color: AppTheme.accentGood,
                  fontSize: AppTextSize.sm,
                  fontWeight: FontWeight.w600)),
        ]),
      );
    }

    // ── Free tier: watch-ad + premium button + banner ───────────────────────
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          color: AppTheme.surfaceHigh,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
          child: Row(children: [
            // Watch ad button
            GestureDetector(
              onTap: (_watchLoading || !freemiumService.canWatchRewarded())
                  ? null
                  : _watch,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _watchLoading
                      ? const SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.play_circle_outline,
                          size: 15, color: AppTheme.primary),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    _watchLoading
                        ? (isEs ? 'Cargando...' : 'Loading...')
                        : (isEs ? '60 min sin anuncios' : '60 min ad-free'),
                    style: TextStyle(
                        fontSize: AppTextSize.xs, color: AppTheme.primary),
                  ),
                ]),
              ),
            ),
            const Spacer(),
            // Get Premium button
            GestureDetector(
              onTap: () => IAPService.instance.buy(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.smPlus, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.workspace_premium,
                      size: 14, color: Colors.white),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(isEs ? 'Obtener Premium' : 'Get Premium',
                      style: const TextStyle(
                          fontSize: AppTextSize.xs,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ]),
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
          ]),
        ),
        if (_bannerLoaded && _banner != null)
          SizedBox(
            width: double.infinity,
            height: _banner!.size.height.toDouble(),
            child: AdWidget(ad: _banner!),
          )
        else
          const SizedBox(
              height: 50), // AdSize.banner fixed height — intentional
      ]),
    );
  }
}
