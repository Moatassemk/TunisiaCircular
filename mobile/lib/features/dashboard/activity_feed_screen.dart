import 'package:flutter/material.dart';

import 'package:clac_mobile/core/api_client.dart';
import 'package:clac_mobile/core/app_theme.dart';
import 'package:clac_mobile/shared/widgets.dart';

class ActivityFeedScreen extends StatefulWidget {
  const ActivityFeedScreen({required this.user, required this.api, super.key});
  final Map<String, dynamic> user;
  final ApiClient api;

  @override
  State<ActivityFeedScreen> createState() => _ActivityFeedScreenState();
}

class _ActivityFeedScreenState extends State<ActivityFeedScreen> {
  late Future<List<dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.transactions();
  }

  Future<void> refresh() async {
    final request = widget.api.transactions();
    setState(() {
      future = request;
    });
    await request;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: FutureBuilder<List<dynamic>>(
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
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const EmptyStateMobile(
              title: 'No activity yet',
              body: 'Transactions and matches will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 9),
              itemBuilder: (context, index) {
                final item = Map<String, dynamic>.from(items[index] as Map);
                final status = item['status']?.toString() ?? 'pending';
                final icon = _iconForStatus(status);
                final color = _colorForStatus(status);
                return Card(
                  color: Theme.of(context).cardTheme.color,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                    side: const BorderSide(color: Color(0xFFE1E6DF)),
                  ),
                  child: ListTile(
                    leading: Icon(icon, color: color, size: 20),
                    title: Text(
                      materialLabel(item['waste_type']),
                      style: const TextStyle(
                        color: pineDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${formatValue(item['amount_kg'])} kg · ${item['gouvernorat'] ?? 'Tunisia'}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    trailing: StatusPill(status),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  IconData _iconForStatus(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'collected':
        return Icons.local_shipping;
      case 'processed':
        return Icons.autorenew;
      case 'matched':
        return Icons.handshake;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case 'completed':
        return pine;
      case 'collected':
      case 'matched':
        return amber;
      case 'processed':
        return pine;
      case 'cancelled':
        return Colors.red;
      default:
        return muted;
    }
  }
}
