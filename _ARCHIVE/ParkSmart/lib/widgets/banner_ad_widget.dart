import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/ads/ad_service.dart';
import '../core/config/ad_config.dart';
import '../core/services/freemium_service.dart';

/// Banner ad widget for ParkSmart.
/// Shows a 320×50 banner for free users; invisible for premium/rewarded.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});
  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _retried = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _ad = BannerAd(
      adUnitId: AdService.bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (!mounted) return;
          setState(() {
            _ad = null;
            _loaded = false;
          });
          if (!_retried) {
            _retried = true;
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) _load();
            });
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdConfig.adsEnabled) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: freemiumService.isPremiumNotifier,
      builder: (_, p, __) => ValueListenableBuilder<bool>(
        valueListenable: freemiumService.isRewardedNotifier,
        builder: (_, __, ___) {
          if (freemiumService.hasFullAccess) return const SizedBox.shrink();
          if (!_loaded || _ad == null) {
            return const SizedBox(width: double.infinity, height: 50);
          }
          return SafeArea(
            top: false,
            left: false,
            right: false,
            child: SizedBox(
              width: _ad!.size.width.toDouble(),
              height: _ad!.size.height.toDouble(),
              child: AdWidget(ad: _ad!),
            ),
          );
        },
      ),
    );
  }
}
