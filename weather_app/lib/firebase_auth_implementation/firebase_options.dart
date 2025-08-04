import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBG76Xe-U-1XXeevaBpoTUXq3v43BNKFlE',
    authDomain: 'weather-3bd18.firebaseapp.com',
    projectId: 'weather-3bd18',
    storageBucket: 'weather-3bd18.firebasestorage.app',
    messagingSenderId: '841896115697',
    appId: '1:841896115697:web:4c8e58db31857019f71850',
    measurementId: 'G-CNE3400NV5',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_ANDROID_API_KEY', // Replace with actual Android API key from Firebase Console
    appId: 'YOUR_ANDROID_APP_ID',   // Replace with actual Android App ID
    messagingSenderId: '841896115697',
    projectId: 'weather-3bd18',
    storageBucket: 'weather-3bd18.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',     // Replace with actual iOS API key from Firebase Console
    appId: 'YOUR_IOS_APP_ID',       // Replace with actual iOS App ID
    messagingSenderId: '841896115697',
    projectId: 'weather-3bd18',
    storageBucket: 'weather-3bd18.firebasestorage.app',
    iosBundleId: 'YOUR_BUNDLE_ID',  // Replace with actual iOS Bundle ID
  );
}