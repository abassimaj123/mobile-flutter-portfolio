// AdMob configuration — test IDs for debug, production IDs for release
// Android: GADApplicationIdentifier set in AndroidManifest.xml ✅
// TODO: iOS — add GADApplicationIdentifier to ios/Runner/Info.plist
// TODO: iOS — create separate iOS ad unit IDs in AdMob console
// TODO: iOS — implement ATT before AdMob init (AppTrackingTransparency)
class AdConfig {
  AdConfig._();

  // TODO: set to false and fill production IDs before Play Store release
  static const bool _useTestIds = true;

  // App ID (set in AndroidManifest.xml / Info.plist — these are for reference)
  static String get appId => _useTestIds
      ? 'ca-app-pub-3940256099942544~3347511713'
      : 'ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX';

  // Banner ad
  static String get bannerId => _useTestIds
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  // Interstitial ad
  static String get interstitialId => _useTestIds
      ? 'ca-app-pub-3940256099942544/1033173712'
      : 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  // Rewarded ad
  static String get rewardedId => _useTestIds
      ? 'ca-app-pub-3940256099942544/5224354917'
      : 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';

  // Feature flags
  static const bool adsEnabled = true;
}
