# Firebase Registration

JobOfferUS currently shares appId with another app.
To get unique analytics and Crashlytics data:

  cd D:\mob\JobOfferUS
  flutterfire configure --project=android-app-54282

This will:
- Register a new Android app in Firebase console
- Update android/app/google-services.json
- Update lib/core/firebase/firebase_options.dart with unique appId

After running, verify the new appId in firebase_options.dart
differs from other apps in the portfolio.
