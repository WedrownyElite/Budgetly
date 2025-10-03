// budgetly/lib/screens/backup_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/cloud_sync_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final CloudSyncService _syncService = CloudSyncService();
  List<BackupMetadata> _backups = [];
  bool _isLoading = true;
  bool _isCreatingBackup = false;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _checkOnlineStatus();
    _loadBackups();
  }

  Future<void> _checkOnlineStatus() async {
    final online = await _syncService.isOnline();
    setState(() => _isOnline = online);
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    final backups = await _syncService.listBackups();
    setState(() {
      _backups = backups;
      _isLoading = false;
    });
  }

  Future<void> _createBackup() async {
    setState(() => _isCreatingBackup = true);

    final result = await _syncService.createBackup();

    setState(() => _isCreatingBackup = false);

    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadBackups();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Backup failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _restoreBackup(BackupMetadata backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Backup'),
        content: Text(
          'This will replace all current data with the backup from ${DateFormat('MMM d, yyyy h:mm a').format(backup.createdAt)}.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Restoring backup...'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final result = await _syncService.restoreBackup(backup.backupId);

    if (mounted) {
      Navigator.pop(context); // Close loading dialog

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup restored successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Restore failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteBackup(BackupMetadata backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Backup'),
        content: const Text('Are you sure you want to delete this backup? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _syncService.deleteBackup(backup.backupId);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup deleted')),
        );
        _loadBackups();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete backup'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cloud Backup'),
      ),
      body: Column(
        children: [
          // Status Banner
          Container(
            padding: const EdgeInsets.all(16),
            color: _isOnline
                ? Colors.green.withValues(alpha: 0.1)
                : Colors.orange.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(
                  _isOnline ? Icons.cloud_done : Icons.cloud_off,
                  color: _isOnline ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isOnline ? 'Connected' : 'Offline',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isOnline ? Colors.green : Colors.orange,
                        ),
                      ),
                      Text(
                        _isOnline
                            ? 'Ready to backup and sync'
                            : 'Connect to internet to backup',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Create Backup Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCreatingBackup || !_isOnline ? null : _createBackup,
                icon: _isCreatingBackup
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.backup),
                label: Text(_isCreatingBackup ? 'Creating Backup...' : 'Create New Backup'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),

          // Backups List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _backups.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 64,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No backups yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first backup to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[600] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _backups.length,
              itemBuilder: (context, index) {
                final backup = _backups[index];
                return _buildBackupCard(backup, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCard(BackupMetadata backup, bool isDark) {
    final isFromThisDevice = backup.deviceId != null; // You'd check against current device ID

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.backup,
            color: Color(0xFF6366F1),
            size: 24,
          ),
        ),
        title: Text(
          DateFormat('MMM d, yyyy').format(backup.createdAt),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              DateFormat('h:mm a').format(backup.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isFromThisDevice ? Icons.phone_android : Icons.devices,
                  size: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
                const SizedBox(width: 4),
                Text(
                  isFromThisDevice ? 'This device' : 'Other device',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  'Transactions',
                  '${backup.transactionCount}',
                  Icons.receipt,
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Budgets',
                  '${backup.budgetCount}',
                  Icons.account_balance_wallet,
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Goals',
                  '${backup.goalCount}',
                  Icons.flag,
                  isDark,
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  'Size',
                  backup.sizeFormatted,
                  Icons.storage,
                  isDark,
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _restoreBackup(backup),
                        icon: const Icon(Icons.restore, size: 18),
                        label: const Text('Restore'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteBackup(backup),
                        icon: const Icon(Icons.delete, size: 18),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}