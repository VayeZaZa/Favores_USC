// File generated for FAVORES USC Firebase Project (favores-u-s-c-r4lrye)
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opciones oficiales de conexión para Firebase del proyecto FAVORES USC
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
          'DefaultFirebaseOptions no está configurado para macOS.',
        );
      case TargetPlatform.windows:
        return web;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para Linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions no soporta esta plataforma.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB7PoDqgDOFRhWn_oWFa8fPfYV65afOPKw',
    appId: '1:491546356558:web:0f0bf0463979fa5df5cc1f',
    messagingSenderId: '491546356558',
    projectId: 'favores-u-s-c-r4lrye',
    authDomain: 'favores-u-s-c-r4lrye.firebaseapp.com',
    storageBucket: 'favores-u-s-c-r4lrye.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB7PoDqgDOFRhWn_oWFa8fPfYV65afOPKw',
    appId: '1:491546356558:android:c6940a4fde47b6c6f5cc1f',
    messagingSenderId: '491546356558',
    projectId: 'favores-u-s-c-r4lrye',
    storageBucket: 'favores-u-s-c-r4lrye.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB7PoDqgDOFRhWn_oWFa8fPfYV65afOPKw',
    appId: '1:491546356558:ios:0f0bf0463979fa5df5cc1f',
    messagingSenderId: '491546356558',
    projectId: 'favores-u-s-c-r4lrye',
    storageBucket: 'favores-u-s-c-r4lrye.firebasestorage.app',
    iosBundleId: 'com.usc.favoresUsc',
  );
}
