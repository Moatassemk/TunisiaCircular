import 'package:flutter/material.dart';

import 'package:clac_mobile/core/api_client.dart';
import 'package:clac_mobile/shared/widgets.dart';

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({
    required this.user,
    required this.api,
    required this.transactionId,
    super.key,
  });
  final Map<String, dynamic> user;
  final ApiClient api;
  final String transactionId;

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late Future<Map<String, dynamic>> future;
  late Future<List<dynamic>> messages;
  final message = TextEditingController();
  bool updating = false;
  bool sending = false;
  bool scheduling = false;

  @override
  void initState() {
    super.initState();
    future = widget.api.getTransaction(widget.transactionId);
    messages = widget.api.transactionMessages(widget.transactionId);
  }

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final next = widget.api.getTransaction(widget.transactionId);
    final nextMessages = widget.api.transactionMessages(widget.transactionId);
    setState(() {
      future = next;
      messages = nextMessages;
    });
    await Future.wait([next, nextMessages]);
  }

  List<String> _actions(Map<String, dynamic> exchange) {
    final role = widget.user['role'];
    final status = exchange['status'];
    if (role == 'admin') {
      return const [
        'pending',
        'matched',
        'collected',
        'processed',
        'completed',
        'cancelled',
      ];
    }
    if (status == 'pending') {
      return role == 'generator'
          ? const ['matched', 'cancelled']
          : const ['cancelled'];
    }
    if (status == 'matched') return const ['collected', 'cancelled'];
    if (status == 'collected') return const ['processed'];
    if (status == 'processed') return const ['completed'];
    return const [];
  }

  String _actionLabel(String status) => switch (status) {
    'matched' => 'Accept request',
    'collected' => 'Confirm pickup',
    'processed' => 'Confirm processing',
    'completed' => 'Complete exchange',
    'cancelled' =>
      widget.user['role'] == 'generator' ? 'Decline request' : 'Cancel request',
    _ => status,
  };

  Future<void> _changeStatus(String status) async {
    setState(() => updating = true);
    try {
      await widget.api.updateStatus(widget.transactionId, status);
      await refresh();
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  Future<void> _sendMessage() async {
    final body = message.text.trim();
    if (body.isEmpty) return;
    setState(() => sending = true);
    try {
      await widget.api.sendTransactionMessage(widget.transactionId, body);
      message.clear();
      await refresh();
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _schedulePickup() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null || !mounted) return;
    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => scheduling = true);
    try {
      await widget.api.schedulePickup(widget.transactionId, scheduled);
      await refresh();
    } catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => scheduling = false);
    }
  }

  void _showError(String value) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(value.replaceFirst('Exception: ', ''))),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Exchange details')),
    body: FutureBuilder<Map<String, dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorState(
            message: snapshot.error.toString(),
            onRetry: refresh,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final exchange = snapshot.data!;
        final status = exchange['status']?.toString() ?? 'pending';
        final actions = _actions(exchange);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.toUpperCase(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    _detail('Seller', exchange['generator_name']),
                    _detail('Buyer', exchange['processor_name']),
                    _detail('Material', materialLabel(exchange['waste_type'])),
                    _detail('Quantity', '${exchange['amount_kg']} kg'),
                    if (exchange['scheduled_pickup_at'] != null)
                      _detail(
                        'Pickup scheduled',
                        DateTime.tryParse(
                              exchange['scheduled_pickup_at'].toString(),
                            )?.toLocal().toString() ??
                            '—',
                      ),
                    if (exchange['notes']?.toString().isNotEmpty == true)
                      _detail('Request notes', exchange['notes']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Exchange progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _timeline(exchange),
            if (status == 'pending' || status == 'matched') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: scheduling ? null : _schedulePickup,
                icon: scheduling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.event_available_outlined),
                label: Text(
                  exchange['scheduled_pickup_at'] == null
                      ? 'Schedule pickup'
                      : 'Change pickup time',
                ),
              ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (updating)
                const Center(child: CircularProgressIndicator())
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: actions
                      .map(
                        (action) => FilledButton.tonal(
                          onPressed: () => _changeStatus(action),
                          child: Text(_actionLabel(action)),
                        ),
                      )
                      .toList(),
                ),
            ],
            const SizedBox(height: 24),
            Text('Messages', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FutureBuilder<List<dynamic>>(
              future: messages,
              builder: (context, thread) {
                if (thread.hasError) {
                  return Text('Messages could not load: ${thread.error}');
                }
                if (!thread.hasData) {
                  return const LinearProgressIndicator();
                }
                if (thread.data!.isEmpty) {
                  return const Text(
                    'Coordinate collection details with the other organization here.',
                  );
                }
                return Column(
                  children: thread.data!.map((raw) {
                    final row = Map<String, dynamic>.from(raw as Map);
                    final mine =
                        row['sender_id'] ==
                        (widget.user['id'] ?? widget.user['user_id']);
                    return Align(
                      alignment: mine
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Card(
                        color: mine
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                row['sender_name']?.toString() ?? 'CLAC member',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 520,
                                ),
                                child: Text(row['body']?.toString() ?? ''),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: message,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: 4000,
                    decoration: const InputDecoration(
                      labelText: 'Message the other organization',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: sending ? null : _sendMessage,
                  icon: sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );

  Widget _detail(String label, dynamic value) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(label, style: const TextStyle(color: Colors.black54)),
        ),
        Expanded(
          child: Text(
            value?.toString() ?? '—',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );

  Widget _timeline(Map<String, dynamic> exchange) {
    const steps = ['pending', 'matched', 'collected', 'processed', 'completed'];
    final status = exchange['status']?.toString() ?? 'pending';
    final current = steps.indexOf(status);
    final events = (exchange['events'] as List? ?? const [])
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();
    Map<String, dynamic>? eventFor(String step) {
      for (final event in events) {
        if (event['to_status'] == step) return event;
      }
      return null;
    }

    String titleFor(String step) => switch (step) {
      'pending' => 'Request submitted',
      'matched' => 'Request accepted',
      'collected' => 'Pickup confirmed',
      'processed' => 'Processing confirmed',
      'completed' => 'Exchange completed',
      'cancelled' => 'Exchange cancelled',
      _ => step,
    };

    String? subtitleFor(Map<String, dynamic>? event) {
      if (event == null) return null;
      final actor = event['actor_name']?.toString();
      final time = DateTime.tryParse(event['created_at']?.toString() ?? '');
      final details = <String>[
        if (actor != null && actor.isNotEmpty) actor,
        if (time != null)
          MaterialLocalizations.of(context).formatMediumDate(time.toLocal()),
        if (time != null)
          MaterialLocalizations.of(
            context,
          ).formatTimeOfDay(TimeOfDay.fromDateTime(time.toLocal())),
      ];
      return details.isEmpty ? null : details.join(' · ');
    }

    final displayedSteps = status == 'cancelled'
        ? [...steps, 'cancelled']
        : steps;
    return Column(
      children: displayedSteps.indexed.map((entry) {
        final (index, step) = entry;
        final event = eventFor(step);
        final complete = step == 'cancelled' ? event != null : current >= index;
        return ListTile(
          dense: true,
          leading: Icon(
            complete ? Icons.check_circle : Icons.radio_button_unchecked,
            color: complete ? Colors.green : Colors.grey,
          ),
          title: Text(titleFor(step)),
          subtitle: subtitleFor(event) != null
              ? Text(subtitleFor(event)!)
              : null,
          contentPadding: EdgeInsets.zero,
        );
      }).toList(),
    );
  }
}
