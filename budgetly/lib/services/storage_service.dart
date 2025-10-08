// budgetly/lib/services/storage_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:convert';
import 'dart:typed_data';
import '../utils/constants.dart';
import 'secure_key_manager.dart';

class StorageService {
  final _storage = const FlutterSecureStorage();
  final _firestore = FirebaseFirestore.instance;
  final _keyManager = SecureKeyManager();

  String _getUserKey(String baseKey, String userId) {
    return '${baseKey}_$userId';
  }
  
  // Local storage (for current session)
  Future<String?> getAccessToken({String? userId}) async {
    if (userId == null) return null;
    final key = _getUserKey(AppConstants.accessTokenKey, userId);
    return await _storage.read(key: key);
  }

  Future<void> saveAccessToken(String token, String userId) async {
    final key = _getUserKey(AppConstants.accessTokenKey, userId);
    await _storage.write(key: key, value: token);
  }

  Future<void> deleteAccessToken(String userId) async {
    final key = _getUserKey(AppConstants.accessTokenKey, userId);
    await _storage.delete(key: key);
  }

  Future<String> _encryptData(String plainText) async {
    try {
      // Get the encryption key from SecureKeyManager (ensures 32 characters)
      final encryptionKey = await _keyManager.getEncryptionKey();

      // Convert to bytes and ensure it's exactly 32 bytes
      final keyBytes = utf8.encode(encryptionKey);
      if (keyBytes.length != 32) {
        throw Exception('Encryption key must be exactly 32 bytes');
      }

      final key = encrypt.Key(Uint8List.fromList(keyBytes));
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

  Future<String> _decryptData(String encryptedText) async {
    try {
      final combined = base64.decode(encryptedText);

      // Extract IV (first 16 bytes) and encrypted data
      final iv = encrypt.IV(Uint8List.fromList(combined.take(16).toList()));
      final encryptedBytes = Uint8List.fromList(combined.skip(16).toList());

      // Get the encryption key from SecureKeyManager
      final encryptionKey = await _keyManager.getEncryptionKey();
      final keyBytes = utf8.encode(encryptionKey);
      if (keyBytes.length != 32) {
        throw Exception('Encryption key must be exactly 32 bytes');
      }

      final key = encrypt.Key(Uint8List.fromList(keyBytes));

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
      final encryptedToken = await _encryptData(accessToken);
      await _firestore.collection('users').doc(userId).set({
        'plaid_access_token': encryptedToken,
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
          return await _decryptData(encryptedToken);
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