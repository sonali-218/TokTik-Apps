// PLANTILLA — este archivo lo SOBRESCRIBE `flutterfire configure`.
//
// Los valores de abajo son de relleno solo para que el proyecto compile
// antes de configurarlo. Corre en la raíz del proyecto:
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=clase23-firebase-demo
//
// y elige las plataformas android e ios.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Corre `flutterfire configure` para web.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'Plataforma no configurada. Corre `flutterfire configure`.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB3B_h2sZFIqWUcvscnsK3jkPIONPt-niI',
    appId: '1:675459793875:android:ecdb26c7ac6b550b91e526',
    messagingSenderId: '675459793875',
    projectId: 'clase23-firebase-demo',
    storageBucket: 'clase23-firebase-demo.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBMDps8czahBKOnCSTy4aqcRa561FxEmFY',
    appId: '1:675459793875:ios:9a149c51fe23a51b91e526',
    messagingSenderId: '675459793875',
    projectId: 'clase23-firebase-demo',
    storageBucket: 'clase23-firebase-demo.firebasestorage.app',
    iosBundleId: 'com.alissonquijano.toktik',
  );
}
