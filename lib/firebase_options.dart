// File generated for Firebase configuration.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAp7DnTXTJVdLc1cNA9Pjy2nhQNaR2yzU4',
    appId: '1:713617302599:android:d0a937d92c5e78a706bd62',
    messagingSenderId: '713617302599',
    projectId: 'payk-app-loyalty',
    storageBucket: 'payk-app-loyalty.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBQSYZD2i8ZATgRICIj1H33kQM2ud4NjE8',
    appId: '1:713617302599:ios:d8a2940f3d3a0c8506bd62',
    messagingSenderId: '713617302599',
    projectId: 'payk-app-loyalty',
    storageBucket: 'payk-app-loyalty.firebasestorage.app',
    iosBundleId: 'app.payk.payk',
  );
}
