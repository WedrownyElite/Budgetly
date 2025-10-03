import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
              'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
              'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
              'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDGZ43XJxrTHs0oJNkY-a6c7J0T7D0Xepk',
    appId: '1:950810331303:web:6302c7ea5b97f6f9c5f382',
    messagingSenderId: '950810331303',
    projectId: 'budgetly-2a825',
    authDomain: 'budgetly-2a825.firebaseapp.com',
    storageBucket: 'budgetly-2a825.firebasestorage.app',
    measurementId: 'G-LQ6DHSC277',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDpUNuzJjbxb3EyO3vgrXb2Ep8cBI9DomU',
    appId: '1:950810331303:android:b5b8dfaf798ac625c5f382',
    messagingSenderId: '950810331303',
    projectId: 'budgetly-2a825',
    storageBucket: 'budgetly-2a825.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDTVkpT4CNlNC_sTomqaiBff2qK2sVmOTs',
    appId: '1:950810331303:ios:7419f1d373bb0403c5f382',
    messagingSenderId: '950810331303',
    projectId: 'budgetly-2a825',
    storageBucket: 'budgetly-2a825.firebasestorage.app',
    iosBundleId: 'com.oddologyinc.budgetly',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDTVkpT4CNlNC_sTomqaiBff2qK2sVmOTs',
    appId: '1:950810331303:ios:7419f1d373bb0403c5f382',
    messagingSenderId: '950810331303',
    projectId: 'budgetly-2a825',
    storageBucket: 'budgetly-2a825.firebasestorage.app',
    iosBundleId: 'com.oddologyinc.budgetly',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDGZ43XJxrTHs0oJNkY-a6c7J0T7D0Xepk',
    appId: '1:950810331303:web:1acd06fda9f3464bc5f382',
    messagingSenderId: '950810331303',
    projectId: 'budgetly-2a825',
    authDomain: 'budgetly-2a825.firebaseapp.com',
    storageBucket: 'budgetly-2a825.firebasestorage.app',
    measurementId: 'G-JB11VN6LFK',
  );
}
