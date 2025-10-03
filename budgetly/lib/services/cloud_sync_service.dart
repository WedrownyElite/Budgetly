// budgetly/lib/services/cloud_sync_service.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ADD THIS
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import '../models/transaction.dart' as models;
import '../models/budget.dart';
import '../models/financial_goal.dart';
import 'transaction_storage_service.dart';
import 'budget_storage_service.dart';
import 'secure_key_manager.dart';

class CloudSyncService {
  // Singleton pattern
  static final CloudSyncService _instance = CloudSyncService._internal();
  factory CloudSyncService() => _instance;
  CloudSyncService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TransactionStorageService _transactionStorage = TransactionStorageService();
  final BudgetStorageService _budgetStorage = BudgetStorageService();
  final SecureKeyManager _keyManager = SecureKeyManager();

  String? _userId;
  String? _deviceId;
  String? _encryptionKey;
  bool _isInitialized = false;

  /// Initialize cloud sync with user ID
  Future<void> initialize(String userId) async {
    _userId = userId;
    _deviceId = await _keyManager.getDeviceId();
    _encryptionKey = await _keyManager.getEncryptionKey();
    _isInitialized = true;

    if (kDebugMode) {
      debugPrint('✅ CloudSyncService initialized: userId=$_userId, deviceId=$_deviceId, hasEncryptionKey=${_encryptionKey != null}');
    }
  }

  /// Check if user is authenticated - NOW PROPERLY CHECKS FIREBASE AUTH
  bool get isAuthenticated {
    // Check both local userId AND Firebase Auth state
    return _isInitialized &&
        _userId != null &&
        _auth.currentUser != null &&
        _auth.currentUser!.uid == _userId;
  }

  /// Get current authenticated user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Debug method - helps diagnose auth issues
  Future<Map<String, dynamic>> getAuthDebugInfo() async {
    return {
      'local_userId': _userId,
      'firebase_currentUser': _auth.currentUser?.uid,
      'firebase_isSignedIn': _auth.currentUser != null,
      'isAuthenticated': isAuthenticated,
      'isInitialized': _isInitialized,
      'encryption_key_exists': _encryptionKey != null,
      'device_id': _deviceId,
    };
  }

  /// Check network connectivity
  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return !connectivityResult.contains(ConnectivityResult.none);
  }

  // ============================================================================
  // BACKUP OPERATIONS
  // ============================================================================

  /// Create a full backup of all app data
  Future<BackupResult> createBackup() async {
    // IMPROVED: Check Firebase Auth directly
    if (_auth.currentUser == null) {
      return BackupResult.failure('User not authenticated. Please log in again.');
    }

    // Auto-initialize if not initialized but user is signed in
    if (!_isInitialized) {
      final currentUserId = _auth.currentUser!.uid;
      if (kDebugMode) {
        debugPrint('⚠️ CloudSyncService not initialized, auto-initializing with userId: $currentUserId');
      }
      await initialize(currentUserId);
    }

    // Verify userId matches current user
    final currentUserId = _auth.currentUser!.uid;
    if (_userId != currentUserId) {
      // Reinitialize with correct userId
      if (kDebugMode) {
        debugPrint('⚠️ UserId mismatch. Local: $_userId, Firebase: $currentUserId. Re-initializing...');
      }
      await initialize(currentUserId);
    }

    if (!await isOnline()) {
      return BackupResult.failure('No internet connection');
    }

    try {
      // Collect all data
      final transactions = await _transactionStorage.loadTransactions();
      final budgets = await _budgetStorage.getBudgets();
      final goals = await _budgetStorage.getGoals();
      final customCategories = await _transactionStorage.loadCustomCategories();

      final backupData = {
        'version': '1.0',
        'created_at': DateTime.now().toIso8601String(),
        'device_id': _deviceId,
        'data': {
          'transactions': transactions.map((t) => t.toJson()).toList(),
          'budgets': budgets.map((b) => b.toJson()).toList(),
          'goals': goals.map((g) => g.toJson()).toList(),
          'custom_categories': customCategories,
        }
      };

      // Encrypt data
      final encryptedData = _encryptData(jsonEncode(backupData));

      // Create backup file
      final backupId = const Uuid().v4();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'backup_${timestamp}_$backupId.bak';

      // Upload to Cloud Storage with proper userId
      final ref = _storage.ref('users/$currentUserId/backups/$fileName');
      final uploadTask = ref.putString(encryptedData);

      await uploadTask;

      // Save metadata to Firestore with proper userId
      await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('backups')
          .doc(backupId)
          .set({
        'backup_id': backupId,
        'file_name': fileName,
        'created_at': FieldValue.serverTimestamp(),
        'device_id': _deviceId,
        'transaction_count': transactions.length,
        'budget_count': budgets.length,
        'goal_count': goals.length,
        'size_bytes': encryptedData.length,
      });

      return BackupResult.success(backupId, fileName);
    } on FirebaseAuthException catch (e) {
      // Handle auth-specific errors
      if (kDebugMode) {
        debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      }
      return BackupResult.failure('Authentication error: ${e.message}');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Backup creation error: $e');
      }
      return BackupResult.failure('Backup failed: $e');
    }
  }

  /// List all available backups
  Future<List<BackupMetadata>> listBackups() async {
    if (_auth.currentUser == null) return [];

    final currentUserId = _auth.currentUser!.uid;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('backups')
          .orderBy('created_at', descending: true)
          .limit(20)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return BackupMetadata(
          backupId: data['backup_id'] as String,
          fileName: data['file_name'] as String,
          createdAt: (data['created_at'] as Timestamp).toDate(),
          deviceId: data['device_id'] as String?,
          transactionCount: data['transaction_count'] as int,
          budgetCount: data['budget_count'] as int,
          goalCount: data['goal_count'] as int,
          sizeBytes: data['size_bytes'] as int,
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error listing backups: $e');
      }
      return [];
    }
  }

  /// Restore from a specific backup
  Future<RestoreResult> restoreBackup(String backupId) async {
    if (_auth.currentUser == null) {
      return RestoreResult.failure('User not authenticated');
    }

    final currentUserId = _auth.currentUser!.uid;

    try {
      // Get backup metadata
      final metadataDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('backups')
          .doc(backupId)
          .get();

      if (!metadataDoc.exists) {
        return RestoreResult.failure('Backup not found');
      }

      final fileName = metadataDoc.data()!['file_name'] as String;

      // Download backup file
      final ref = _storage.ref('users/$currentUserId/backups/$fileName');
      final encryptedData = await ref.getData();

      if (encryptedData == null) {
        return RestoreResult.failure('Failed to download backup');
      }

      // Decrypt data
      final decryptedData = _decryptData(String.fromCharCodes(encryptedData));
      final backupData = jsonDecode(decryptedData) as Map<String, dynamic>;

      // Restore data
      final data = backupData['data'] as Map<String, dynamic>;

      // Restore transactions
      final transactions = (data['transactions'] as List)
          .map((json) => models.Transaction.fromJson(json))
          .toList();
      await _transactionStorage.saveTransactions(transactions);

      // Restore budgets
      final budgets = (data['budgets'] as List)
          .map((json) => Budget.fromJson(json))
          .toList();
      await _budgetStorage.saveBudgets(budgets);

      // Restore goals
      final goals = (data['goals'] as List)
          .map((json) => FinancialGoal.fromJson(json))
          .toList();
      await _budgetStorage.saveGoals(goals);

      // Restore custom categories
      final customCategories = (data['custom_categories'] as List)
          .map((e) => e.toString())
          .toList();
      await _transactionStorage.saveCustomCategories(customCategories);

      return RestoreResult.success();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Restore error: $e');
      }
      return RestoreResult.failure('Restore failed: $e');
    }
  }

  /// Delete a backup
  Future<bool> deleteBackup(String backupId) async {
    if (_auth.currentUser == null) return false;

    final currentUserId = _auth.currentUser!.uid;

    try {
      // Get backup metadata
      final metadataDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('backups')
          .doc(backupId)
          .get();

      if (!metadataDoc.exists) return false;

      final fileName = metadataDoc.data()!['file_name'] as String;

      // Delete from storage
      final ref = _storage.ref('users/$currentUserId/backups/$fileName');
      await ref.delete();

      // Delete metadata
      await metadataDoc.reference.delete();

      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting backup: $e');
      }
      return false;
    }
  }

  // ============================================================================
  // REAL-TIME SYNC OPERATIONS
  // ============================================================================

  /// Enable real-time sync (listen to changes)
  Stream<SyncEvent> enableRealtimeSync() {
    if (_auth.currentUser == null) {
      return Stream.error('User not authenticated');
    }

    final currentUserId = _auth.currentUser!.uid;

    return _firestore
        .collection('users')
        .doc(currentUserId)
        .collection('sync_events')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return SyncEvent.idle();
      }

      final doc = snapshot.docs.first;
      final data = doc.data();

      return SyncEvent(
        eventType: data['event_type'] as String,
        timestamp: (data['timestamp'] as Timestamp).toDate(),
        deviceId: data['device_id'] as String,
        changes: data['changes'] as Map<String, dynamic>?,
      );
    });
  }

  /// Sync transactions to cloud
  Future<bool> syncTransactions(List<models.Transaction> transactions) async {
    if (_auth.currentUser == null || !await isOnline()) return false;

    final currentUserId = _auth.currentUser!.uid;

    try {
      final batch = _firestore.batch();

      for (var transaction in transactions) {
        final docRef = _firestore
            .collection('users')
            .doc(currentUserId)
            .collection('transactions')
            .doc(transaction.id);

        batch.set(docRef, {
          ...transaction.toJson(),
          'synced_at': FieldValue.serverTimestamp(),
          'device_id': _deviceId,
        }, SetOptions(merge: true));
      }

      await batch.commit();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Sync failed: $e');
      }
      return false;
    }
  }

  /// Pull transactions from cloud
  Future<List<models.Transaction>> pullTransactions({DateTime? since}) async {
    if (_auth.currentUser == null) return [];

    final currentUserId = _auth.currentUser!.uid;

    try {
      Query query = _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('transactions');

      if (since != null) {
        query = query.where('synced_at', isGreaterThan: Timestamp.fromDate(since));
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        return models.Transaction.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Pull failed: $e');
      }
      return [];
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  String _encryptData(String plainText) {
    if (_encryptionKey == null) {
      throw Exception('Encryption key not initialized. Call initialize() first.');
    }
    final key = encrypt.Key.fromUtf8(_encryptionKey!);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  String _decryptData(String encryptedText) {
    if (_encryptionKey == null) {
      throw Exception('Encryption key not initialized. Call initialize() first.');
    }
    final parts = encryptedText.split(':');
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
    final key = encrypt.Key.fromUtf8(_encryptionKey!);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.decrypt(encrypted, iv: iv);
  }
}

// Data models remain the same...
class BackupMetadata {
  final String backupId;
  final String fileName;
  final DateTime createdAt;
  final String? deviceId;
  final int transactionCount;
  final int budgetCount;
  final int goalCount;
  final int sizeBytes;

  BackupMetadata({
    required this.backupId,
    required this.fileName,
    required this.createdAt,
    this.deviceId,
    required this.transactionCount,
    required this.budgetCount,
    required this.goalCount,
    required this.sizeBytes,
  });

  String get sizeFormatted {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class BackupResult {
  final bool success;
  final String? backupId;
  final String? fileName;
  final String? errorMessage;

  BackupResult.success(this.backupId, this.fileName)
      : success = true,
        errorMessage = null;

  BackupResult.failure(this.errorMessage)
      : success = false,
        backupId = null,
        fileName = null;
}

class RestoreResult {
  final bool success;
  final String? errorMessage;

  RestoreResult.success()
      : success = true,
        errorMessage = null;

  RestoreResult.failure(this.errorMessage) : success = false;
}

class SyncEvent {
  final String eventType;
  final DateTime timestamp;
  final String deviceId;
  final Map<String, dynamic>? changes;

  SyncEvent({
    required this.eventType,
    required this.timestamp,
    required this.deviceId,
    this.changes,
  });

  SyncEvent.idle()
      : eventType = 'idle',
        timestamp = DateTime.now(),
        deviceId = '',
        changes = null;
}