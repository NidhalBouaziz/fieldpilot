import 'package:firebase_core/firebase_core.dart';

class FirebaseBootstrap {
  static bool _configured = false;

  static bool get configured => _configured;

  static Future<void> initialize() async {
    if (Firebase.apps.isNotEmpty) {
      _configured = true;
      return;
    }

    const envOptions = FirebaseOptions(
      apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
      appId: String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    );

    final hasEnvOptions = envOptions.apiKey.isNotEmpty &&
        envOptions.appId.isNotEmpty &&
        envOptions.projectId.isNotEmpty;

    try {
      await Firebase.initializeApp(
        options: hasEnvOptions ? envOptions : null,
      );
      _configured = true;
    } on UnsupportedError {
      await _tryNativeDefaultInitialization();
    } on FirebaseException catch (error) {
      if (error.code == 'duplicate-app') {
        _configured = true;
        return;
      }
      _configured = false;
    }
  }

  static Future<void> _tryNativeDefaultInitialization() async {
    try {
      await Firebase.initializeApp();
      _configured = true;
    } on FirebaseException catch (error) {
      _configured = error.code == 'duplicate-app';
    } catch (_) {
      _configured = false;
    }
  }
}
