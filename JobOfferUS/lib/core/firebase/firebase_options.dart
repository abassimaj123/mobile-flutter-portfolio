import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return android; // fallback — iOS TODO Phase 2
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAVdM2OBORjb4fgCtWiqCwOJkkc5yhPRSY',
    appId: '1:123456789:android:joboffer',
    messagingSenderId: '385086392226',
    projectId: 'android-app-54282',
    storageBucket: 'android-app-54282.firebasestorage.app',
  );
}
