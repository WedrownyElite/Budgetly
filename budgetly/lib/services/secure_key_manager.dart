// budgetly/lib/services/secure_key_manager.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';
import 'dart:convert';

class SecureKeyManager {
  static final SecureKeyManager _instance = SecureKeyManager._internal();
  factory SecureKeyManager() => _instance;
  SecureKeyManager._internal();

  // Simple initialization that works with all versions
  final _storage = const FlutterSecureStorage();

  static const String _encryptionKeyName = 'budgetly_encryption_key';
  static const String _deviceIdKeyName = 'budgetly_device_id';

  /// Get or create the encryption key
  /// This key is used for encrypting backups
  Future<String> getEncryptionKey() async {
    try {
      // Try to read existing key
      String? key = await _storage.read(key: _encryptionKeyName);

      // If no key exists, generate a new one
      if (key == null || key.isEmpty) {
        key = _generateSecureKey();
        await _storage.write(key: _encryptionKeyName, value: key);
      }

      return key;
    } catch (e) {
      throw Exception('Failed to get encryption key: $e');
    }
  }

  /// Get or create a persistent device ID
  Future<String> getDeviceId() async {
    try {
      String? deviceId = await _storage.read(key: _deviceIdKeyName);

      if (deviceId == null || deviceId.isEmpty) {
        deviceId = _generateDeviceId();
        await _storage.write(key: _deviceIdKeyName, value: deviceId);
      }

      return deviceId;
    } catch (e) {
      throw Exception('Failed to get device ID: $e');
    }
  }

  /// Regenerate encryption key (use with caution - will make old backups unreadable)
  Future<String> regenerateEncryptionKey() async {
    final newKey = _generateSecureKey();
    await _storage.write(key: _encryptionKeyName, value: newKey);
    return newKey;
  }

  /// Delete all secure data (for logout/reset)
  Future<void> clearAllSecureData() async {
    await _storage.deleteAll();
  }

  /// Delete only the encryption key
  Future<void> deleteEncryptionKey() async {
    await _storage.delete(key: _encryptionKeyName);
  }

  /// Check if encryption key exists
  Future<bool> hasEncryptionKey() async {
    final key = await _storage.read(key: _encryptionKeyName);
    return key != null && key.isNotEmpty;
  }

  // Generate a cryptographically secure 32-character key
  String _generateSecureKey() {
    final random = Random.secure();
    final values = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(values).substring(0, 32);
  }

  // Generate a unique device ID
  String _generateDeviceId() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }
}