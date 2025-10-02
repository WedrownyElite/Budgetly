// budgetly/lib/services/cloud_sync_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import '../models/transaction.dart';
import '../models/budget.dart';
import '../models/financial_goal.dart';
import 'transaction_storage_service.dart';
import 'budget_storage_service.dart';

class CloudSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TransactionStorageService _transactionStorage = TransactionStorageService();
  final BudgetStorageService _budgetStorage = BudgetStorageService();

  String? _userId;
  String? _deviceId;

  // Encryption key - in production, derive from user password or store securely
  static const String _encryptionKey = 'your-32-character-secret-key!!'; // Change this!

  /// Initialize cloud sync with user ID
  Future<void> initialize(String userId) async {
    _userId = userId;
    _deviceId = await _getOrCreateDeviceId();
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _userId != null;

  /// Check network connectivity
  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // ============================================================================
  // BACKUP OPERATIONS
  // ============================================================================

  /// Create a full backup of all app data
  Future<BackupResult> createBackup() async {
    if (!isAuthenticated) {
      return BackupResult.failure('User not authenticated');
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

      // Upload to Cloud Storage
      final ref = _storage.ref('users/$_userId/backups/$fileName');
      final uploadTask = ref.putString(encryptedData);

      await uploadTask;

      // Save metadata to Firestore
      await _firestore
          .collection('users')
          .doc(_userId)
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
    } catch (e) {
      return BackupResult.failure('Backup failed: $e');
    }
  }

  /// List all available backups
  Future<List<BackupMetadata>> listBackups() async {
    if (!isAuthenticated) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_userId)
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
      print('Error listing backups: $e');
      return [];
    }
  }

  /// Restore from a specific backup
  Future<RestoreResult> restoreBackup(String backupId) async {
    if (!isAuthenticated) {
      return RestoreResult.failure('User not authenticated');
    }

    try {
      // Get backup metadata
      final metadataDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('backups')
          .doc(backupId)
          .get();

      if (!metadataDoc.exists) {
        return RestoreResult.failure('Backup not found');
      }

      final fileName = metadataDoc.data()!['file_name'] as String;

      // Download backup file
      final ref = _storage.ref('users/$_userId/backups/$fileName');
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
          .map((json) => Transaction.fromJson(json))
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
      return RestoreResult.failure('Restore failed: $e');
    }
  }

  /// Delete a backup
  Future<bool> deleteBackup(String backupId) async {
    if (!isAuthenticated) return false;

    try {
      // Get backup metadata
      final metadataDoc = await _firestore
          .collection('users')
          .doc(_userId)
          .collection('backups')
          .doc(backupId)
          .get();

      if (!metadataDoc.exists) return false;

      final fileName = metadataDoc.data()!['file_name'] as String;

      // Delete from storage
      final ref = _storage.ref('users/$_userId/backups/$fileName');
      await ref.delete();

      // Delete metadata
      await metadataDoc.reference.delete();

      return true;
    } catch (e) {
      print('Error deleting backup: $e');
      return false;
    }
  }

  // ============================================================================
  // REAL-TIME SYNC OPERATIONS
  // ============================================================================

  /// Enable real-time sync (listen to changes)
  Stream<SyncEvent> enableRealtimeSync() {
    if (!isAuthenticated) {
      return Stream.error('User not authenticated');
    }

    return _firestore
        .collection('users')
        .doc(_userId)
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
  Future<bool> syncTransactions(List<Transaction> transactions) async {
    if (!isAuthenticated || !await isOnline()) return false;

    try {
      final batch = _firestore.batch();

      for (var transaction in transactions) {
        final docRef = _firestore
            .collection('users')
            .doc(_userId)
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
      print('Sync failed: $e');
      return false;
    }
  }

  /// Pull transactions from cloud
  Future<List<Transaction>> pullTransactions({DateTime? since}) async {
    if (!isAuthenticated) return [];

    try {
      Query query = _firestore
          .collection('users')
          .doc(_userId)
          .collection('transactions');

      if (since != null) {
        query = query.where('synced_at', isGreaterThan: Timestamp.fromDate(since));
      }

      final snapshot = await query.get();

      return snapshot.docs.map((doc) {
        return Transaction.fromJson(doc.data());
      }).toList();
    } catch (e) {
      print('Pull failed: $e');
      return [];
    }
  }

  // ============================================================================
  // UTILITY METHODS
  // ============================================================================

  Future<String> _getOrCreateDeviceId() async {
    // In production, use device_info_plus or similar
    return const Uuid().v4();
  }

  String _encryptData(String plainText) {
    final key = encrypt.Key.fromUtf8(_encryptionKey);
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  String _decryptData(String encryptedText) {
    final parts = encryptedText.split(':');
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
    final key = encrypt.Key.fromUtf8(_encryptionKey);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    return encrypter.decrypt(encrypted, iv: iv);
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

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