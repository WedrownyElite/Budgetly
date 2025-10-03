// budgetly/lib/screens/calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/subscription.dart';
import '../models/transaction.dart';
import '../models/recurring_transaction.dart';
import '../services/subscription_service.dart';

class CalendarScreen extends StatefulWidget {
  final List<Transaction> transactions;

  const CalendarScreen({super.key, required this.transactions});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  List<ManagedSubscription> _subscriptions = [];
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    // Get managed subscriptions
    final managedSubs = await _subscriptionService.getSubscriptions(widget.transactions);

    // Detect recurring transactions
    final recurring = RecurringTransactionDetector.detectRecurring(widget.transactions);
    final subscriptionRecurring = recurring.where((r) => r.isSubscription).toList();

    // Create calendar items from both sources
    final List<ManagedSubscription> calendarItems = [];

    // Add managed subscriptions
    calendarItems.addAll(managedSubs.where((s) =>
    s.status == SubscriptionStatus.active &&
        s.nextBillingDate != null
    ));

    // Add unmanaged recurring subscriptions with estimated dates
    for (var recurringTxn in subscriptionRecurring) {
      // Check if already managed
      final isManaged = managedSubs.any((s) =>
      s.merchantName.toLowerCase() == recurringTxn.merchantName.toLowerCase()
      );

      if (!isManaged) {
        // Create a temporary managed subscription with estimated next billing
        final nextBilling = _estimateNextBilling(recurringTxn);

        calendarItems.add(ManagedSubscription(
          id: 'temp_${recurringTxn.merchantName}',
          merchantName: recurringTxn.merchantName,
          recurringTransaction: recurringTxn,
          status: SubscriptionStatus.active,
          nextBillingDate: nextBilling,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    }

    if (mounted) {
      setState(() {
        _subscriptions = calendarItems;
        _isLoading = false;
      });
    }
  }

  DateTime _estimateNextBilling(RecurringTransaction recurring) {
    final lastDate = recurring.lastOccurrence;
    final now = DateTime.now();

    // Calculate next billing based on frequency
    DateTime estimated;
    switch (recurring.frequency) {
      case RecurrenceFrequency.weekly:
        estimated = lastDate.add(const Duration(days: 7));
        break;
      case RecurrenceFrequency.biWeekly:
        estimated = lastDate.add(const Duration(days: 14));
        break;
      case RecurrenceFrequency.monthly:
        estimated = DateTime(lastDate.year, lastDate.month + 1, lastDate.day);
        break;
      case RecurrenceFrequency.quarterly:
        estimated = DateTime(lastDate.year, lastDate.month + 3, lastDate.day);
        break;
      case RecurrenceFrequency.yearly:
        estimated = DateTime(lastDate.year + 1, lastDate.month, lastDate.day);
        break;
    }

    // If estimated date is in the past, keep adding intervals until future
    while (estimated.isBefore(now)) {
      switch (recurring.frequency) {
        case RecurrenceFrequency.weekly:
          estimated = estimated.add(const Duration(days: 7));
          break;
        case RecurrenceFrequency.biWeekly:
          estimated = estimated.add(const Duration(days: 14));
          break;
        case RecurrenceFrequency.monthly:
          estimated = DateTime(estimated.year, estimated.month + 1, estimated.day);
          break;
        case RecurrenceFrequency.quarterly:
          estimated = DateTime(estimated.year, estimated.month + 3, estimated.day);
          break;
        case RecurrenceFrequency.yearly:
          estimated = DateTime(estimated.year + 1, estimated.month, estimated.day);
          break;
      }
    }

    return estimated;
  }

  List<ManagedSubscription> _getPaymentsForDay(DateTime day) {
    return _subscriptions.where((sub) {
      if (sub.nextBillingDate == null) return false;
      return isSameDay(sub.nextBillingDate!, day);
    }).toList();
  }

  double _getTotalForDay(DateTime day) {
    final payments = _getPaymentsForDay(day);
    return payments.fold(0.0, (sum, sub) =>
    sum + sub.recurringTransaction.averageAmount
    );
  }

  double _getMonthTotal(DateTime month) {
    double total = 0;
    final Set<String> counted = {}; // Track which subscriptions we've counted

    // Get all days in the month
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    // Check each day in the month
    for (var day = firstDay; day.isBefore(lastDay.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
      for (var sub in _subscriptions) {
        if (sub.nextBillingDate == null) continue;

        // Check if this subscription bills on this day
        if (isSameDay(sub.nextBillingDate!, day)) {
          // Only count each subscription once per month
          if (!counted.contains(sub.merchantName)) {
            total += sub.recurringTransaction.averageAmount;
            counted.add(sub.merchantName);
          }
        }
      }
    }

    return total;
  }

  int _getPaymentCountForMonth(DateTime month) {
    final Set<String> counted = {}; // Track unique subscriptions

    // Get all days in the month
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    // Check each day in the month
    for (var day = firstDay; day.isBefore(lastDay.add(const Duration(days: 1))); day = day.add(const Duration(days: 1))) {
      for (var sub in _subscriptions) {
        if (sub.nextBillingDate == null) continue;

        // Check if this subscription bills on this day
        if (isSameDay(sub.nextBillingDate!, day)) {
          counted.add(sub.merchantName);
        }
      }
    }

    return counted.length;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment Calendar')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final selectedPayments = _getPaymentsForDay(_selectedDay);
    final selectedTotal = _getTotalForDay(_selectedDay);
    final monthTotal = _getMonthTotal(_focusedDay);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Calendar'),
      ),
      body: Column(
        children: [
          // Month Summary
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1F29) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'This Month',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${monthTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                ),
                Column(
                  children: [
                    Text(
                      'Payments',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_getPaymentCountForMonth(_focusedDay)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Calendar
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              calendarFormat: CalendarFormat.month,
              startingDayOfWeek: StartingDayOfWeek.sunday,
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: const BoxDecoration(
                  color: Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                markersMaxCount: 1,
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              eventLoader: (day) {
                final payments = _getPaymentsForDay(day);
                return payments;
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, date, events) {
                  if (events.isEmpty) return const SizedBox();

                  final total = _getTotalForDay(date);

                  return Positioned(
                    bottom: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        '\$${total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  );
                },
              ),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                setState(() {
                  _focusedDay = focusedDay;
                });
              },
            ),
          ),

          const SizedBox(height: 16),

          // Selected Day Details
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1F29) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatDate(_selectedDay),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (selectedPayments.isNotEmpty)
                              Text(
                                '${selectedPayments.length} payment${selectedPayments.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                        if (selectedTotal > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '\$${selectedTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: selectedPayments.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_available,
                            size: 48,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No payments due',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.grey[500] : Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                        : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: selectedPayments.length,
                      itemBuilder: (context, index) {
                        final subscription = selectedPayments[index];
                        return _buildPaymentCard(subscription, isDark);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(ManagedSubscription subscription, bool isDark) {
    final recurring = subscription.recurringTransaction;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: recurring.category.group.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.subscriptions,
                color: recurring.category.group.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subscription.merchantName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    recurring.frequency.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '\$${recurring.averageAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == tomorrow) {
      return 'Tomorrow';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }
}