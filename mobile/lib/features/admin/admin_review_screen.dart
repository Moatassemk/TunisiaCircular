import 'package:flutter/material.dart';

import 'package:clac_mobile/core/api_client.dart';
import 'package:clac_mobile/core/app_theme.dart';
import 'package:clac_mobile/shared/widgets.dart';
import 'package:clac_mobile/shared/strings.dart';

class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({required this.api, super.key});
  final ApiClient api;

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<dynamic>> future;
  final Set<String> busyIds = {};
  bool organizations = false;
  late TabController _tabController;
  late Future<Map<String, dynamic>> _statsFuture;
  late Future<List<dynamic>> _usersFuture;
  final Set<String> _togglingUsers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    future = widget.api.adminCollectionPoints();
    _statsFuture = widget.api.adminStats();
    _usersFuture = widget.api.adminUsers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final next = organizations
        ? widget.api.adminOrganizations()
        : widget.api.adminCollectionPoints();
    setState(() {
      future = next;
    });
    await next;
  }

  void toggleQueue() {
    setState(() {
      organizations = !organizations;
      future = organizations
          ? widget.api.adminOrganizations()
          : widget.api.adminCollectionPoints();
    });
  }

  Future<void> review(
    String id, {
    required bool approve,
    String reason = '',
  }) async {
    setState(() => busyIds.add(id));
    try {
      if (organizations && approve) {
        await widget.api.verifyOrganization(id);
      } else if (organizations) {
        await widget.api.rejectOrganization(id);
      } else if (approve) {
        await widget.api.verifyCollectionPoint(id);
      } else {
        await widget.api.rejectCollectionPoint(id, reason: reason);
      }
      if (mounted) {
        setState(() {
          busyIds.remove(id);
          future = organizations
              ? widget.api.adminOrganizations()
              : widget.api.adminCollectionPoints();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.clac(
                organizations
                    ? (approve
                          ? 'Organization verified.'
                          : 'Organization submission rejected.')
                    : (approve
                          ? 'Collection point approved.'
                          : 'Submission rejected.'),
              ),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => busyIds.remove(id));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Review failed: $error')));
      }
    }
  }

  Future<void> _rejectWithReason(String id) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectionReasonDialog(),
    );
    if (reason == null || reason.isEmpty || !mounted) return;
    await review(id, approve: false, reason: reason);
  }

  Future<void> _refreshAdminData() async {
    setState(() {
      _statsFuture = widget.api.adminStats();
      _usersFuture = widget.api.adminUsers();
    });
    await Future.wait([_statsFuture, _usersFuture]);
  }

  Future<void> _toggleUser(String userId) async {
    setState(() => _togglingUsers.add(userId));
    try {
      await widget.api.toggleUserActive(userId);
      if (mounted) {
        setState(() => _togglingUsers.remove(userId));
        await _refreshAdminData();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _togglingUsers.remove(userId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to toggle user: $error')),
        );
      }
    }
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _refreshAdminData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              context.clac('Admin Overview'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          _buildStatsCards(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              context.clac('User Management'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<dynamic>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return ErrorState(
                  message: snapshot.error.toString(),
                  onRetry: _refreshAdminData,
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snapshot.data!;
              if (users.isEmpty) {
                return const Center(
                  child: Text(
                    'No users found.',
                    style: TextStyle(color: muted),
                  ),
                );
              }
              return Column(
                children: users.map((raw) {
                  final user = Map<String, dynamic>.from(raw as Map);
                  final userId = user['id'].toString();
                  final isActive = user['is_active'] == true;
                  final isToggling = _togglingUsers.contains(userId);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isActive
                            ? const Color(0xFFE8F2E9)
                            : const Color(0xFFF4F6F1),
                        child: Icon(
                          isActive ? Icons.check_circle : Icons.cancel_outlined,
                          color: isActive ? pine : muted,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        user['name']?.toString().isNotEmpty == true
                            ? user['name'].toString()
                            : user['email']?.toString() ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${user['role'] ?? ''} · ${user['gouvernorat'] ?? ''}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: isToggling
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : OutlinedButton(
                              onPressed: () => _toggleUser(userId),
                              child: Text(
                                isActive
                                    ? context.clac('Inactive')
                                    : context.clac('Active'),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorState(
            message: snapshot.error.toString(),
            onRetry: _refreshAdminData,
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final stats = snapshot.data!;
        return Row(
          children: [
            Expanded(
              child: _StatTile(
                label: context.clac('Total Users'),
                value: stats['totalUsers']?.toString() ?? '0',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(
                label: context.clac('Total Transactions'),
                value: stats['totalTransactions']?.toString() ?? '0',
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.clac('Review')),
            Tab(text: context.clac('Admin Overview')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildReviewTab(), _buildOverviewTab()],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.place_outlined, size: 17),
                      label: Text('Points'),
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.business_outlined, size: 17),
                      label: Text('Organizations'),
                    ),
                  ],
                  selected: {organizations},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) {
                    if (value.first != organizations) toggleQueue();
                  },
                ),
              ),
              IconButton(
                tooltip: context.clac('Refresh'),
                onPressed: refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(child: _buildReviewList()),
      ],
    );
  }

  Widget _buildReviewList() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
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
          final points = snapshot.data!;
          if (points.isEmpty) {
            return EmptyStateMobile(
              title: context.clac('Nothing to review'),
              body: context.clac(
                organizations
                    ? 'New organization profiles will appear here.'
                    : 'New collection point submissions will appear here.',
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: points.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final point = Map<String, dynamic>.from(points[index] as Map);
                final id = point['id'].toString();
                final busy = busyIds.contains(id);
                if (organizations) {
                  return _organizationCard(context, point, id, busy);
                }
                final accepted =
                    (point['accepts_waste_types'] as List? ?? const [])
                        .map(materialLabel)
                        .join(', ');
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              child: Icon(Icons.add_location_alt_outlined),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    point['name']?.toString() ??
                                        'Collection point',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    '${humanStatus(point['point_type']?.toString())} · ${point['gouvernorat'] ?? ''}',
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            StatusPill(
                              point['is_verified'] == true
                                  ? 'Verified'
                                  : 'Pending',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if ((point['address'] ?? '').toString().isNotEmpty)
                          Text(point['address'].toString()),
                        Text(
                          '${context.clac('Coordinates:')} ${point['lat']}, ${point['lng']}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (accepted.isNotEmpty)
                          Text(
                            '${context.clac('Materials:')} $accepted',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (point['description']?.toString().isNotEmpty == true)
                          Text(
                            point['description'].toString(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          '${context.clac('Submitted by')} ${point['submitter_name'] ?? point['submitter_email'] ?? 'CLAC member'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => _rejectWithReason(id),
                                icon: const Icon(Icons.close),
                                label: Text(context.clac('Reject')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => review(id, approve: true),
                                icon: busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.verified_outlined),
                                label: Text(context.clac('Approve')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _organizationCard(
    BuildContext context,
    Map<String, dynamic> organization,
    String id,
    bool busy,
  ) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.business_outlined)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      organization['company_name']?.toString().isNotEmpty ==
                              true
                          ? organization['company_name'].toString()
                          : organization['name']?.toString() ?? 'Organization',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${organization['role']} · ${organization['gouvernorat'] ?? ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Chip(label: Text('Pending')),
            ],
          ),
          const SizedBox(height: 10),
          Text(organization['email']?.toString() ?? ''),
          if (organization['phone']?.toString().isNotEmpty == true)
            Text(organization['phone'].toString()),
          if (organization['description']?.toString().isNotEmpty == true)
            Text(organization['description'].toString()),
          if (organization['lat'] != null && organization['lng'] != null)
            Text(
              'Location: ${organization['lat']}, ${organization['lng']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : () => review(id, approve: false),
                  icon: const Icon(Icons.close),
                  label: Text(context.clac('Reject')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : () => review(id, approve: true),
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_outlined),
                  label: Text(context.clac('Verify organization')),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _RejectionReasonDialog extends StatefulWidget {
  const _RejectionReasonDialog();

  @override
  State<_RejectionReasonDialog> createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<_RejectionReasonDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Why is this being rejected?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'The owner will see this note and can fix the submission before resubmitting.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'e.g. The pin is outside the stated address.',
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          final note = controller.text.trim();
          if (note.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add a short reason first.')),
            );
            return;
          }
          Navigator.pop(context, note);
        },
        child: const Text('Reject submission'),
      ),
    ],
  );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 7),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
