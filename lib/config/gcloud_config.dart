import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GcloudConfig {
  static const String fileName = 'gcloud.conf';

  static Future<void> load() async {
    await dotenv.load(fileName: fileName);
    final gcloudEnv = Map<String, String>.from(dotenv.env);

    try {
      await dotenv.load(
        fileName: '.env',
        mergeWith: gcloudEnv,
        isOptional: true,
      );
    } catch (error) {
      debugPrint('WARNING: Failed to load optional .env file: $error');
      await dotenv.load(fileName: fileName);
    }

    _validateRequiredKeys();
  }

  static FirebaseOptions get firebaseOptions {
    if (kIsWeb) return _webOptions;

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidOptions;
      case TargetPlatform.iOS:
        return _iosOptions;
      case TargetPlatform.macOS:
        return _macosOptions;
      case TargetPlatform.windows:
        return _windowsOptions;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'Firebase options have not been configured for Linux in $fileName.',
        );
      default:
        throw UnsupportedError(
          'Firebase options are not supported for this platform.',
        );
    }
  }

  static String get apiBaseUrl => _trimTrailingSlash(_required('API_BASE_URL'));
  static String get gcsBucketName => _required('GCS_BUCKET_NAME');
  static String get gcsFunctionUrl =>
      _trimTrailingSlash(_required('GCS_FUNCTION_URL'));

  static FirebaseOptions get _webOptions => FirebaseOptions(
    apiKey: _required('FIREBASE_WEB_API_KEY'),
    appId: _required('FIREBASE_WEB_APP_ID'),
    messagingSenderId: _required('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _required('FIREBASE_PROJECT_ID'),
    authDomain: _required('FIREBASE_WEB_AUTH_DOMAIN'),
    storageBucket: _required('FIREBASE_STORAGE_BUCKET'),
    measurementId: _optional('FIREBASE_WEB_MEASUREMENT_ID'),
  );

  static FirebaseOptions get _androidOptions => FirebaseOptions(
    apiKey: _required('FIREBASE_ANDROID_API_KEY'),
    appId: _required('FIREBASE_ANDROID_APP_ID'),
    messagingSenderId: _required('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _required('FIREBASE_PROJECT_ID'),
    storageBucket: _required('FIREBASE_STORAGE_BUCKET'),
  );

  static FirebaseOptions get _iosOptions => FirebaseOptions(
    apiKey: _required('FIREBASE_IOS_API_KEY'),
    appId: _required('FIREBASE_IOS_APP_ID'),
    messagingSenderId: _required('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _required('FIREBASE_PROJECT_ID'),
    storageBucket: _required('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: _required('FIREBASE_IOS_BUNDLE_ID'),
  );

  static FirebaseOptions get _macosOptions => FirebaseOptions(
    apiKey: _required('FIREBASE_MACOS_API_KEY'),
    appId: _required('FIREBASE_MACOS_APP_ID'),
    messagingSenderId: _required('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _required('FIREBASE_PROJECT_ID'),
    storageBucket: _required('FIREBASE_STORAGE_BUCKET'),
    iosBundleId: _required('FIREBASE_MACOS_BUNDLE_ID'),
  );

  static FirebaseOptions get _windowsOptions => FirebaseOptions(
    apiKey: _required('FIREBASE_WINDOWS_API_KEY'),
    appId: _required('FIREBASE_WINDOWS_APP_ID'),
    messagingSenderId: _required('FIREBASE_MESSAGING_SENDER_ID'),
    projectId: _required('FIREBASE_PROJECT_ID'),
    authDomain: _required('FIREBASE_WINDOWS_AUTH_DOMAIN'),
    storageBucket: _required('FIREBASE_STORAGE_BUCKET'),
    measurementId: _optional('FIREBASE_WINDOWS_MEASUREMENT_ID'),
  );

  static void _validateRequiredKeys() {
    final missing = <String>[
      'API_BASE_URL',
      'GCS_BUCKET_NAME',
      'GCS_FUNCTION_URL',
      'FIREBASE_PROJECT_ID',
      'FIREBASE_MESSAGING_SENDER_ID',
      'FIREBASE_STORAGE_BUCKET',
      ..._platformFirebaseKeys,
    ].where((key) => _optional(key) == null).toList();

    if (missing.isNotEmpty) {
      throw StateError(
        'Missing required Google Cloud config in $fileName: '
        '${missing.join(', ')}',
      );
    }
  }

  static List<String> get _platformFirebaseKeys {
    if (kIsWeb) {
      return const [
        'FIREBASE_WEB_API_KEY',
        'FIREBASE_WEB_APP_ID',
        'FIREBASE_WEB_AUTH_DOMAIN',
      ];
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return const ['FIREBASE_ANDROID_API_KEY', 'FIREBASE_ANDROID_APP_ID'];
      case TargetPlatform.iOS:
        return const [
          'FIREBASE_IOS_API_KEY',
          'FIREBASE_IOS_APP_ID',
          'FIREBASE_IOS_BUNDLE_ID',
        ];
      case TargetPlatform.macOS:
        return const [
          'FIREBASE_MACOS_API_KEY',
          'FIREBASE_MACOS_APP_ID',
          'FIREBASE_MACOS_BUNDLE_ID',
        ];
      case TargetPlatform.windows:
        return const [
          'FIREBASE_WINDOWS_API_KEY',
          'FIREBASE_WINDOWS_APP_ID',
          'FIREBASE_WINDOWS_AUTH_DOMAIN',
        ];
      case TargetPlatform.linux:
        return const [];
      default:
        return const [];
    }
  }

  static String _required(String key) {
    final value = _optional(key);
    if (value == null) {
      throw StateError('Missing required config "$key" in $fileName.');
    }
    return value;
  }

  static String? _optional(String key) {
    final value = dotenv.env[key]?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static String _trimTrailingSlash(String value) =>
      value.replaceFirst(RegExp(r'/+$'), '');
}
