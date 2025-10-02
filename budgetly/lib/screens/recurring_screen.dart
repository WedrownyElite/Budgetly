// budgetly/lib/screens/recurring_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/transaction.dart';
import '../models/recurring_transaction.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';
import '../services/accessibility_service.dart';

class RecurringScreen extends StatefulWidget {
  final List<Transaction> transactions;

  const RecurringScreen({super.key, required this.transactions});

  @override
  State<RecurringScreen> createState() => _RecurringScreenState();
}

class _RecurringScreenState extends State<RecurringScreen> with SingleTickerProviderStateMixin {
  final SubscriptionService _subscriptionService = SubscriptionService();
  List<ManagedSubscription> _managedSubscriptions = [];
  List<RecurringTransaction> _allRecurring = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _allRecurring = RecurringTransactionDetector.detectRecurring(widget.transactions);
    _managedSubscriptions = await _subscriptionService.getSubscriptions(widget.transactions);

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _showManageDialog(RecurringTransaction recurring) async {
    final existing = await _subscriptionService.getSubscriptionByMerchant(
      recurring.merchantName,
      widget.transactions,
    );

    if (!mounted) return;

    final result = await showDialog<ManagedSubscription>(
      context: context,
      builder: (context) => _ManageSubscriptionDialog(
        recurring: recurring,
        existing: existing,
      ),
    );

    if (result != null) {
      if (existing != null) {
        await _subscriptionService.updateSubscription(result);
      } else {
        await _subscriptionService.addSubscription(result);
      }
      _loadData();
      if (mounted) {
        AccessibilityService.announce(context, 'Subscription updated');
      }
    }
  }

  double _getTotalMonthlyCost(SubscriptionStatus? filterStatus) {
    return _managedSubscriptions
        .where((s) => filterStatus == null || s.status == filterStatus)
        .fold(0.0, (sum, s) => sum + s.recurringTransaction.monthlyCost);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        body: Semantics(
          label: 'Loading recurring transactions',
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final subscriptions = _allRecurring.where((r) => r.isSubscription).toList();
    final otherRecurring = _allRecurring.where((r) => !r.isSubscription).toList();
    final activeManaged = _managedSubscriptions.where((s) => s.status == SubscriptionStatus.active).toList();
    final unusedSubscriptions = activeManaged.where((s) => s.isUnused).toList();
    final dueSoon = activeManaged.where((s) => s.isDueSoon).toList();

    return Scaffold(
      body: Column(
        children: [
          // Tab Bar
          Container(
            color: isDark ? const Color(0xFF1A1F29) : Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF6366F1),
              labelColor: const Color(0xFF6366F1),
              unselectedLabelColor: isDark ? Colors.grey : Colors.grey.shade600,
              tabs: const [
                Tab(text: 'Subscriptions'),
                Tab(text: 'Other Recurring'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Subscriptions Tab
                _buildSubscriptionsTab(subscriptions, activeManaged, unusedSubscriptions, dueSoon, isDark),
                // Other Recurring Tab
                _buildOtherRecurringTab(otherRecurring, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionsTab(
      List<RecurringTransaction> subscriptions,
      List<ManagedSubscription> activeManaged,
      List<ManagedSubscription> unusedSubscriptions,
      List<ManagedSubscription> dueSoon,
      bool isDark,
      ) {
    if (subscriptions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.subscriptions, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No subscriptions detected'),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Monthly Cost',
                _getTotalMonthlyCost(SubscriptionStatus.active),
                Colors.blue,
                Icons.calendar_month,
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                'Annual Cost',
                _getTotalMonthlyCost(SubscriptionStatus.active) * 12,
                Colors.purple,
                Icons.calendar_today,
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Alerts
        if (unusedSubscriptions.isNotEmpty) ...[
          _buildAlertCard(
            'Unused Subscriptions',
            '${unusedSubscriptions.length} subscription${unusedSubscriptions.length > 1 ? 's' : ''} not used in 30+ days',
            Colors.orange,
            Icons.warning_amber_rounded,
            isDark,
          ),
          const SizedBox(height: 12),
        ],

        if (dueSoon.isNotEmpty) ...[
          _buildAlertCard(
            'Renewals Due Soon',
            '${dueSoon.length} subscription${dueSoon.length > 1 ? 's' : ''} renewing in 3 days',
            Colors.blue,
            Icons.schedule_rounded,
            isDark,
          ),
          const SizedBox(height: 24),
        ],

        // Subscriptions List
        const Text(
          'Your Subscriptions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        ...subscriptions.map((recurring) {
          final managed = _managedSubscriptions
              .where((s) => s.merchantName.toLowerCase() == recurring.merchantName.toLowerCase())
              .firstOrNull;

          return _buildSubscriptionCard(recurring, managed, isDark);
        }),
      ],
    );
  }

  Widget _buildOtherRecurringTab(List<RecurringTransaction> otherRecurring, bool isDark) {
    if (otherRecurring.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.repeat, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No other recurring transactions detected'),
          ],
        ),
      );
    }

    final totalMonthly = otherRecurring.fold(0.0, (sum, r) => sum + r.monthlyCost);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Card
        _buildSummaryCard(
          'Total Monthly',
          totalMonthly,
          Colors.green,
          Icons.repeat,
          isDark,
        ),
        const SizedBox(height: 24),

        const Text(
          'Recurring Transactions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        ...otherRecurring.map((recurring) => _buildRecurringCard(recurring, isDark)),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title,
      double amount,
      Color color,
      IconData icon,
      bool isDark,
      ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '\$${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(
      String title,
      String message,
      Color color,
      IconData icon,
      bool isDark,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(
      RecurringTransaction recurring,
      ManagedSubscription? managed,
      bool isDark,
      ) {
    final status = managed?.status ?? SubscriptionStatus.active;
    final isManaged = managed != null;

    return Semantics(
      button: true,
      label: '\$${recurring.merchantName}, \$${recurring.averageAmount.toStringAsFixed(2)} dollars \$${recurring.frequency.displayName}, \$${status.displayName}, double tap to manage',
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () => _showManageDialog(recurring),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: status.color.withValues(alpha: isDark ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.subscriptions,
                        color: status.color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recurring.merchantName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            recurring.frequency.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${recurring.averageAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '\$${recurring.monthlyCost.toStringAsFixed(2)}/mo',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (isManaged) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: status.color.withValues(alpha: isDark ? 0.25 : 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: status.color,
                          ),
                        ),
                      ),
                      if (managed.nextBillingDate != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF262D3D) : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: isDark ? Colors.white60 : Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Next: ${managed.nextBillingDate!.month}/${managed.nextBillingDate!.day}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.white60 : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (managed.isUnused)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: isDark ? 0.25 : 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Unused 30d',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecurringCard(RecurringTransaction recurring, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: recurring.category.group.color.withValues(alpha: 0.2),
          child: Icon(
            Icons.repeat,
            color: recurring.category.group.color,
            size: 20,
          ),
        ),
        title: Text(
          recurring.merchantName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(recurring.frequency.displayName),
            Text(
              recurring.category.displayName,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${recurring.averageAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              '\$${recurring.monthlyCost.toStringAsFixed(2)}/mo',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Occurrences', '${recurring.occurrenceCount}'),
                _buildDetailRow('Average Amount', '\$${recurring.averageAmount.toStringAsFixed(2)}'),
                _buildDetailRow('Monthly Cost', '\$${recurring.monthlyCost.toStringAsFixed(2)}'),
                _buildDetailRow('Annual Cost', '\$${recurring.annualCost.toStringAsFixed(2)}'),
                _buildDetailRow('Frequency', recurring.frequency.displayName),
                _buildDetailRow(
                  'First Seen',
                  '${recurring.firstOccurrence.month}/${recurring.firstOccurrence.day}/${recurring.firstOccurrence.year}',
                ),
                _buildDetailRow(
                  'Last Seen',
                  '${recurring.lastOccurrence.month}/${recurring.lastOccurrence.day}/${recurring.lastOccurrence.year}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Recent Transactions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ...recurring.transactions.take(5).map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.date,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '\$${t.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// Subscription Management Dialog
class _ManageSubscriptionDialog extends StatefulWidget {
  final RecurringTransaction recurring;
  final ManagedSubscription? existing;

  const _ManageSubscriptionDialog({
    required this.recurring,
    this.existing,
  });

  @override
  State<_ManageSubscriptionDialog> createState() => _ManageSubscriptionDialogState();
}

class _ManageSubscriptionDialogState extends State<_ManageSubscriptionDialog> {
  late SubscriptionStatus _status;
  DateTime? _nextBillingDate;
  String? _notes;
  bool _trackUsage = false;
  DateTime? _lastUsedDate;
  String? _cancellationUrl;
  String? _customerServicePhone;

  final _notesController = TextEditingController();
  final _urlController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.existing != null) {
      _status = widget.existing!.status;
      _nextBillingDate = widget.existing!.nextBillingDate;
      _notes = widget.existing!.notes;
      _trackUsage = widget.existing!.trackUsage;
      _lastUsedDate = widget.existing!.lastUsedDate;
      _cancellationUrl = widget.existing!.cancellationUrl;
      _customerServicePhone = widget.existing!.customerServicePhone;

      _notesController.text = _notes ?? '';
      _urlController.text = _cancellationUrl ?? '';
      _phoneController.text = _customerServicePhone ?? '';
    } else {
      _status = SubscriptionStatus.active;
      final lastTransaction = widget.recurring.lastOccurrence;
      _nextBillingDate = _estimateNextBilling(lastTransaction);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _urlController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  DateTime _estimateNextBilling(DateTime lastDate) {
    switch (widget.recurring.frequency) {
      case RecurrenceFrequency.weekly:
        return lastDate.add(const Duration(days: 7));
      case RecurrenceFrequency.biWeekly:
        return lastDate.add(const Duration(days: 14));
      case RecurrenceFrequency.monthly:
        return DateTime(lastDate.year, lastDate.month + 1, lastDate.day);
      case RecurrenceFrequency.quarterly:
        return DateTime(lastDate.year, lastDate.month + 3, lastDate.day);
      case RecurrenceFrequency.yearly:
        return DateTime(lastDate.year + 1, lastDate.month, lastDate.day);
    }
  }

  void _save() {
    final subscription = ManagedSubscription(
      id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      merchantName: widget.recurring.merchantName,
      recurringTransaction: widget.recurring,
      status: _status,
      nextBillingDate: _nextBillingDate,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      trackUsage: _trackUsage,
      lastUsedDate: _lastUsedDate,
      cancellationUrl: _urlController.text.isEmpty ? null : _urlController.text,
      customerServicePhone: _phoneController.text.isEmpty ? null : _phoneController.text,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    Navigator.pop(context, subscription);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      title: Text('Manage ${widget.recurring.merchantName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cost info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF262D3D) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Average:', style: TextStyle(fontSize: 12)),
                      Text(
                        '\$${widget.recurring.averageAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Monthly:', style: TextStyle(fontSize: 12)),
                      Text(
                        '\$${widget.recurring.monthlyCost.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Annual:', style: TextStyle(fontSize: 12)),
                      Text(
                        '\$${widget.recurring.annualCost.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Status
            DropdownButtonFormField<SubscriptionStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: SubscriptionStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Row(
                    children: [
                      Icon(
                        status == SubscriptionStatus.active
                            ? Icons.check_circle
                            : status == SubscriptionStatus.cancelled
                            ? Icons.cancel
                            : Icons.pause_circle,
                        size: 16,
                        color: status.color,
                      ),
                      const SizedBox(width: 8),
                      Text(status.displayName),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Next billing date
            if (_status == SubscriptionStatus.active) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Next Billing Date'),
                subtitle: Text(
                  _nextBillingDate != null
                      ? '${_nextBillingDate!.month}/${_nextBillingDate!.day}/${_nextBillingDate!.year}'
                      : 'Not set',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _nextBillingDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _nextBillingDate = picked);
                  }
                },
              ),
              const SizedBox(height: 8),

              // Track usage
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Track Usage'),
                subtitle: const Text('Get alerts if unused for 30 days'),
                value: _trackUsage,
                onChanged: (value) {
                  setState(() => _trackUsage = value);
                },
              ),

              if (_trackUsage) ...[
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Last Used Date'),
                  subtitle: Text(
                    _lastUsedDate != null
                        ? '${_lastUsedDate!.month}/${_lastUsedDate!.day}/${_lastUsedDate!.year}'
                        : 'Not set',
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _lastUsedDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setState(() => _lastUsedDate = picked);
                    }
                  },
                ),
              ],
            ],

            const SizedBox(height: 16),

            // Cancellation URL
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Cancellation URL',
                hintText: 'https://...',
                suffixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 16),

            // Customer service phone
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Customer Service Phone',
                hintText: '1-800-...',
                suffixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Add any notes...',
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        if (_urlController.text.isNotEmpty)
          TextButton.icon(
            onPressed: () async {
              final url = Uri.parse(_urlController.text);
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open URL'),
          ),
        if (_phoneController.text.isNotEmpty)
          TextButton.icon(
            onPressed: () async {
              final url = Uri.parse('tel:${_phoneController.text}');
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
            icon: const Icon(Icons.phone),
            label: const Text('Call'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}