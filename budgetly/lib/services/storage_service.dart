// budgetly/lib/services/storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';
import 'dart:typed_data';
import '../utils/constants.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();
  final _firestore = FirebaseFirestore.instance;

  // Local storage (for current session)
  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.accessTokenKey);
  }

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: AppConstants.accessTokenKey, value: token);
  }

  Future<void> deleteAccessToken() async {
    await _storage.delete(key: AppConstants.accessTokenKey);
  }

  String _encryptData(String plainText) {
    try {
      // Use a synchronous approach with a deterministic key derivation
      // Note: In production, you should use _getEncryptionKey() with proper async handling
      final keyBytes = utf8.encode('your-secure-32-char-key-here!!'); // Replace with secure key
      final key = encrypt.Key(Uint8List.fromList(keyBytes.take(32).toList()));
      final iv = encrypt.IV.fromLength(16);

      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypter.encrypt(plainText, iv: iv);

      // Combine IV and encrypted data
      return base64.encode(iv.bytes + encrypted.bytes);
    } catch (e) {
      print('Error encrypting data: $e');
      rethrow;
    }
  }

  String _decryptData(String encryptedText) {
    try {
      final combined = base64.decode(encryptedText);

      // Extract IV (first 16 bytes) and encrypted data
      final iv = encrypt.IV(Uint8List.fromList(combined.take(16).toList()));
      final encryptedBytes = Uint8List.fromList(combined.skip(16).toList());

      final keyBytes = utf8.encode('your-secure-32-char-key-here!!'); // Must match encryption key
      final key = encrypt.Key(Uint8List.fromList(keyBytes.take(32).toList()));

      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypt.Encrypted(encryptedBytes);

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      print('Error decrypting data: $e');
      rethrow;
    }
  }

  // Cloud storage (for persistence across sessions)
  Future<void> savePlaidTokenToCloud(String userId, String accessToken) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'plaid_access_token': _encryptData(accessToken),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving Plaid token to cloud: $e');
      rethrow;
    }
  }

  Future<String?> getPlaidTokenFromCloud(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final encryptedToken = doc.data()?['plaid_access_token'] as String?;
        if (encryptedToken != null) {
          return _decryptData(encryptedToken);
        }
      }
      return null;
    } catch (e) {
      print('Error getting Plaid token from cloud: $e');
      return null;
    }
  }

  Future<void> deletePlaidTokenFromCloud(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'plaid_access_token': FieldValue.delete(),
      });
    } catch (e) {
      print('Error deleting Plaid token from cloud: $e');
    }
  }
}