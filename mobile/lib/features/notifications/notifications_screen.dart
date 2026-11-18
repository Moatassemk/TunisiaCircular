import 'package:flutter/material.dart';
import 'package:clac_mobile/core/api_client.dart';
import 'package:clac_mobile/core/app_theme.dart';
import 'package:clac_mobile/shared/widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    required this.user,
    required this.api,
    this.onUnreadCountChanged,
    super.key,
  });
  final Map<String, dynamic> user;
  final ApiClient api;
  final ValueChanged<int>? onUnreadCountChanged;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<dynamic>> future;
  final Set<String> _readIds = <String>{};
  List<dynamic> _lastItems = <dynamic>[];
  bool marking = false;
  int? _reportedUnreadCount;

  void _reportUnreadCount(List<dynamic> items) {
    final count = items.where((raw) {
      final item = raw as Map;
      return item['read'] != true && !_readIds.contains(item['id']?.toString());
    }).length;
    if (_reportedUnreadCount == count) return;
    _reportedUnreadCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onUnreadCountChanged?.call(count);
    });
  }

  @override
  void initState() {
    super.initState();
    future = widget.api.notifications();
  }

  Future<void> refresh() async {
    final request = widget.api.notifications();
    setState(() {
      future = request;
    });
    await request;
  }

  Future<void> markAllRead(List<dynamic> items) async {
    final unread = items
        .where((raw) {
          final item = raw as Map<String, dynamic>;
          return item['read'] != true &&
              !_readIds.contains(item['id']?.toString());
        })
        .map((raw) => (raw as Map)['id']?.toString())
        .whereType<String>()
        .toList();
    if (unread.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Nothing left to mark.')));
      }
      return;
    }
    setState(() => marking = true);
    try {
      for (final id in unread) {
        await widget.api.markNotificationRead(id);
        if (mounted) _readIds.add(id);
      }
      _reportUnreadCount(items);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not update all.')));
      }
    } finally {
      if (mounted) setState(() => marking = false);
    }
  }

  Future<void> markOneRead(String id) async {
    if (_readIds.contains(id) || !mounted) return;
    try {
      await widget.api.markNotificationRead(id);
      if (mounted) {
        setState(() => _readIds.add(id));
        _reportUnreadCount(_lastItems);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update notification.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Expanded(
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
                _lastItems = items;
                _reportUnreadCount(items);
                if (items.isEmpty) {
                  return const EmptyStateMobile(
                    title: 'No notifications',
                    body:
                        'Updates about requests and matches will show up here.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 90),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final raw = items[index] as Map;
                      final item = Map<String, dynamic>.from(raw);
                      final unread =
                          item['read'] != true &&
                          !_readIds.contains(item['id']?.toString());
                      return Card(
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                          side: BorderSide(
                            color: unread
                                ? const Color(0xFFD89350)
                                : const Color(0xFFE1E6DF),
                          ),
                        ),
                        child: ListTile(
                          onTap: unread && item['id'] != null
                              ? () => markOneRead(item['id'].toString())
                              : null,
                          leading: Icon(
                            unread
                                ? Icons.mark_email_unread_outlined
                                : Icons.mark_email_read_outlined,
                            color: unread ? amber : muted,
                          ),
                          title: Text(
                            item['title']?.toString() ?? 'Notification',
                            style: const TextStyle(
                              color: pineDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            item['message']?.toString() ?? '',
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
