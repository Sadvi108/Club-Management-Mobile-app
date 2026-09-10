import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted storage for the one real secret this client holds: the bearer token.
///
/// The session used to be persisted whole — token included — as a JSON blob in
/// SharedPreferences. That file is plaintext on disk: readable from an ADB backup, from
/// another app on a rooted device, or by anyone with the handset. The token now lives here
/// instead (iOS Keychain / Android EncryptedSharedPreferences), and the profile blob in
/// SharedPreferences is written without it.
///
/// Web has no OS keychain, so `flutter_secure_storage` falls back to browser storage there.
/// That is unavoidable in a browser and matches how the Expo app behaves; on Android and
/// iOS — where the APK actually ships — the token is encrypted at rest.
class SecureStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// In-memory fallback so auth still works if the platform channel throws
  /// (older Android keystores occasionally do). Never written to disk.
  static final Map<String, String> _memory = {};

  static Future<String?> read(String key) async {
    try {
      final v = await _storage.read(key: key);
      if (v != null) return v;
    } catch (e) {
      debugPrint('SecureStore.read failed: $e');
    }
    return _memory[key];
  }

  static Future<void> write(String key, String value) async {
    _memory[key] = value;
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      debugPrint('SecureStore.write failed: $e');
    }
  }

  static Future<void> delete(String key) async {
    _memory.remove(key);
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('SecureStore.delete failed: $e');
    }
  }
}
