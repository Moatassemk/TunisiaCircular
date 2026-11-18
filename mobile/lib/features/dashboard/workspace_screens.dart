import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:clac_mobile/core/api_client.dart';
import 'package:clac_mobile/shared/strings.dart';
import 'package:clac_mobile/core/app_theme.dart';
import 'package:clac_mobile/shared/widgets.dart';
import 'package:clac_mobile/features/network/transaction_detail_screen.dart';

class MobileDashboard extends StatefulWidget {
  const MobileDashboard({
    required this.user,
    required this.api,
    required this.onOpenMarketplace,
    required this.onOpenNotifications,
    required this.onOpenNetwork,
    required this.onOpenImpact,
    required this.onOpenProfile,
    required this.onOpenRequests,
    required this.onOpenAdmin,
    super.key,
  });
  final Map<String, dynamic> user;
  final ApiClient api;
  final VoidCallback onOpenMarketplace;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenNetwork;
  final VoidCallback onOpenImpact;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenRequests;
  final VoidCallback onOpenAdmin;

  @override
  State<MobileDashboard> createState() => _MobileDashboardState();
}

class _MobileDashboardState extends State<MobileDashboard> {
  late Future<List<Map<String, dynamic>>> future;

  bool get isBuyer => widget.user['role'] == 'processor';
  bool get isCollector => widget.user['role'] == 'collector';
  bool get isAdmin => widget.user['role'] == 'admin';
  bool get isVerified => widget.user['is_verified'] == true;

  String get roleLabel => switch (widget.user['role']) {
    'admin' => 'Network administrator',
    'collector' => 'Collection specialist',
    'processor' => 'Recovery partner',
    _ => 'Material seller',
  };

  @override
  void initState() {
    super.initState();
    future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final results = await Future.wait<Map<String, dynamic>>([
      widget.api.dashboard(),
      widget.api.profileSummary(),
    ]);
    return results;
  }

  Future<void> refresh() async {
    final request = _load();
    setState(() {
      future = request;
    });
    await request;
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorState(
          message: friendlyError(snapshot.error!),
          onRetry: refresh,
        );
      }
      if (!snapshot.hasData) return const _DashboardSkeleton();
      final dashboard = snapshot.data![0];
      final summary = snapshot.data![1];
      final stats = Map<String, dynamic>.from(
        dashboard['stats'] as Map? ?? const {},
      );
      final activity = (summary['recent_activity'] as List? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final pendingPoints =
          (int.tryParse(summary['collection_point_count']?.toString() ?? '0') ??
              0) -
          (int.tryParse(
                summary['verified_collection_point_count']?.toString() ?? '0',
              ) ??
              0);
      final name = widget.user['name']?.toString().trim() ?? 'CLAC member';
      final firstName = name.isEmpty ? 'there' : name.split(' ').first;
      final hour = DateTime.now().hour;
      final greeting = hour < 12
          ? 'Good morning'
          : hour < 18
          ? 'Good afternoon'
          : 'Good evening';

      return RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
          children: [
            Row(
              children: [
                InitialsAvatar(name: name, size: 42),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$greeting, $firstName',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        roleLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!isAdmin)
                  StatusPill(
                    isVerified ? 'Verified' : 'Pending review',
                    icon: true,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _HeroCard(
              role: widget.user['role']?.toString() ?? 'generator',
              isVerified: isVerified,
              name: name,
              onPrimary: isAdmin
                  ? widget.onOpenAdmin
                  : widget.onOpenMarketplace,
              secondaryLabel: isBuyer ? 'Open network map' : 'View impact',
              onSecondary: isBuyer ? widget.onOpenNetwork : widget.onOpenImpact,
            ),
            if (!isAdmin && !isVerified) ...[
              const SizedBox(height: 12),
              InfoBanner(
                title: 'Your organization is awaiting verification',
                body:
                    'An administrator is reviewing your profile. You can keep working while verification is in progress.',
                tone: BannerTone.warning,
                actionLabel: 'Review profile',
                onAction: widget.onOpenProfile,
              ),
            ],
            if (isCollector && pendingPoints > 0) ...[
              const SizedBox(height: 12),
              InfoBanner(
                title:
                    '$pendingPoints collection point${pendingPoints == 1 ? '' : 's'} in review',
                body:
                    'Points stay private until an admin verifies them. You can still edit or add more.',
                tone: BannerTone.info,
                actionLabel: 'Manage points',
                onAction: widget.onOpenMarketplace,
              ),
            ],
            const SizedBox(height: 24),
            const Eyebrow('AT A GLANCE'),
            const SizedBox(height: 10),
            _MetricGrid(
              metrics: isAdmin
                  ? [
                      (
                        label: 'Members',
                        value: formatValue(
                          (int.tryParse(
                                    stats['generators']?.toString() ?? '0',
                                  ) ??
                                  0) +
                              (int.tryParse(
                                    stats['processors']?.toString() ?? '0',
                                  ) ??
                                  0),
                        ),
                        hint: 'sellers + buyers',
                        icon: Icons.groups_2_outlined,
                      ),
                      (
                        label: 'Exchanges',
                        value: formatValue(stats['transactions']),
                        hint: 'all time',
                        icon: Icons.receipt_long_outlined,
                      ),
                      (
                        label: 'Waste diverted',
                        value:
                            '${formatValue(stats['totalWasteDivertedKg'])} kg',
                        hint: 'completed',
                        icon: Icons.recycling_outlined,
                      ),
                      (
                        label: 'CO₂ avoided',
                        value:
                            '${formatValue(stats['totalCarbonSavedKgCO2e'])} kg',
                        hint: 'estimated',
                        icon: Icons.eco_outlined,
                      ),
                    ]
                  : isCollector
                  ? [
                      (
                        label: 'Collection points',
                        value: formatValue(summary['collection_point_count']),
                        hint: 'across Tunisia',
                        icon: Icons.add_location_alt_outlined,
                      ),
                      (
                        label: 'Verified points',
                        value: formatValue(
                          summary['verified_collection_point_count'],
                        ),
                        hint: 'publicly visible',
                        icon: Icons.verified_outlined,
                      ),
                      (
                        label: 'Exchanges',
                        value: formatValue(summary['transaction_count']),
                        hint: 'linked to you',
                        icon: Icons.receipt_long_outlined,
                      ),
                      (
                        label: 'Materials moved',
                        value: '${formatValue(summary['transaction_kg'])} kg',
                        hint: 'lifetime volume',
                        icon: Icons.scale_outlined,
                      ),
                    ]
                  : isBuyer
                  ? [
                      (
                        label: 'Potential supply',
                        value: '${formatValue(stats['monthlyPotentialKg'])} kg',
                        hint: 'per month',
                        icon: Icons.inventory_2_outlined,
                      ),
                      (
                        label: 'Active sellers',
                        value: formatValue(stats['generators']),
                        hint: 'in the network',
                        icon: Icons.storefront_outlined,
                      ),
                      (
                        label: 'Your requests',
                        value: formatValue(summary['transaction_count']),
                        hint: 'all time',
                        icon: Icons.receipt_long_outlined,
                      ),
                      (
                        label: 'CO₂ avoided',
                        value: '${formatValue(summary['carbon_saved_kg'])} kg',
                        hint: 'through your deals',
                        icon: Icons.eco_outlined,
                      ),
                    ]
                  : [
                      (
                        label: 'Live listings',
                        value: formatValue(summary['listing_count']),
                        hint: 'owned by you',
                        icon: Icons.inventory_2_outlined,
                      ),
                      (
                        label: 'Monthly volume',
                        value:
                            '${formatValue(summary['monthly_listing_kg'])} kg',
                        hint: 'listed supply',
                        icon: Icons.scale_outlined,
                      ),
                      (
                        label: 'Requests',
                        value: formatValue(summary['transaction_count']),
                        hint: 'all time',
                        icon: Icons.receipt_long_outlined,
                      ),
                      (
                        label: 'CO₂ avoided',
                        value: '${formatValue(summary['carbon_saved_kg'])} kg',
                        hint: 'through exchanges',
                        icon: Icons.eco_outlined,
                      ),
                    ],
            ),
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Quick actions',
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 10),
            _QuickActions(
              actions: isAdmin
                  ? [
                      (
                        label: 'Review queue',
                        icon: Icons.fact_check_outlined,
                        onTap: widget.onOpenAdmin,
                      ),
                      (
                        label: 'Network map',
                        icon: Icons.map_outlined,
                        onTap: widget.onOpenNetwork,
                      ),
                      (
                        label: 'Notifications',
                        icon: Icons.notifications_none_outlined,
                        onTap: widget.onOpenNotifications,
                      ),
                      (
                        label: 'Impact report',
                        icon: Icons.eco_outlined,
                        onTap: widget.onOpenImpact,
                      ),
                    ]
                  : isCollector
                  ? [
                      (
                        label: 'Collection points',
                        icon: Icons.add_location_alt_outlined,
                        onTap: widget.onOpenMarketplace,
                      ),
                      (
                        label: 'Network map',
                        icon: Icons.map_outlined,
                        onTap: widget.onOpenNetwork,
                      ),
                      (
                        label: 'Requests',
                        icon: Icons.receipt_long_outlined,
                        onTap: widget.onOpenRequests,
                      ),
                      (
                        label: 'Impact report',
                        icon: Icons.eco_outlined,
                        onTap: widget.onOpenImpact,
                      ),
                    ]
                  : isBuyer
                  ? [
                      (
                        label: 'Browse supply',
                        icon: Icons.storefront_outlined,
                        onTap: widget.onOpenMarketplace,
                      ),
                      (
                        label: 'Network map',
                        icon: Icons.map_outlined,
                        onTap: widget.onOpenNetwork,
                      ),
                      (
                        label: 'Requests',
                        icon: Icons.receipt_long_outlined,
                        onTap: widget.onOpenRequests,
                      ),
                      (
                        label: 'Impact report',
                        icon: Icons.eco_outlined,
                        onTap: widget.onOpenImpact,
                      ),
                    ]
                  : [
                      (
                        label: 'List materials',
                        icon: Icons.add_box_outlined,
                        onTap: widget.onOpenMarketplace,
                      ),
                      (
                        label: 'Network map',
                        icon: Icons.map_outlined,
                        onTap: widget.onOpenNetwork,
                      ),
                      (
                        label: 'Requests',
                        icon: Icons.receipt_long_outlined,
                        onTap: widget.onOpenRequests,
                      ),
                      (
                        label: 'Impact report',
                        icon: Icons.eco_outlined,
                        onTap: widget.onOpenImpact,
                      ),
                    ],
            ),
            const SizedBox(height: 24),
            _SetupChecklist(
              isVerified: isVerified,
              isAdmin: isAdmin,
              isBuyer: isBuyer,
              isCollector: isCollector,
              hasListing:
                  (int.tryParse(summary['listing_count']?.toString() ?? '0') ??
                      0) >
                  0,
              hasPoint:
                  (int.tryParse(
                        summary['collection_point_count']?.toString() ?? '0',
                      ) ??
                      0) >
                  0,
              hasExchange:
                  (int.tryParse(
                        summary['transaction_count']?.toString() ?? '0',
                      ) ??
                      0) >
                  0,
              onOpenProfile: widget.onOpenProfile,
              onOpenMarketplace: widget.onOpenMarketplace,
            ),
            const SizedBox(height: 26),
            SectionHeader(
              title: 'Recent activity',
              actionLabel: activity.isEmpty ? null : 'All requests',
              onAction: activity.isEmpty ? null : widget.onOpenRequests,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 10),
            if (activity.isEmpty)
              ClacCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.timeline_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 26,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isCollector
                          ? 'Your collection exchanges will appear here.'
                          : 'Your exchange activity will appear here.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )
            else
              ...activity
                  .take(4)
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ActivityTile(
                        item: item,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TransactionDetailScreen(
                              user: widget.user,
                              api: widget.api,
                              transactionId: item['id'].toString(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 24),
            _NetworkPulse(stats: stats, onOpen: widget.onOpenNetwork),
          ],
        ),
      );
    },
  );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.role,
    required this.isVerified,
    required this.name,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });
  final String role;
  final bool isVerified;
  final String name;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    final (title, body, action) = switch (role) {
      'admin' => (
        'Keep the network honest.',
        'Review new organizations and collection points, and keep quality high across Tunisia.',
        'Open review queue',
      ),
      'collector' => (
        'Grow your collection network.',
        'Add drop-off and pickup points, then turn verified locations into exchanges.',
        'Manage collection points',
      ),
      'processor' => (
        'Source the material you need.',
        'Find sellers that match your accepted materials, distance and capacity.',
        'Browse available supply',
      ),
      _ => (
        'Put your materials to work.',
        'Publish what you have and connect with recovery partners across Tunisia.',
        'Go to my materials',
      ),
    };
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16412F), Color(0xFF2C7658)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(clacRadiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -46,
            top: -54,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .055),
              ),
            ),
          ),
          Positioned(
            right: 30,
            bottom: -54,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF5C77C).withValues(alpha: .11),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isVerified ? 'VERIFIED MEMBER' : 'MEMBER WORKSPACE',
                        style: const TextStyle(
                          color: Color(0xFFD9EEE0),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: Colors.white,
                    fontSize: 27,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFFD2E5D8),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 17),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: onPrimary,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFF5C77C),
                        foregroundColor: const Color(0xFF2C1B09),
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      child: Text(action),
                    ),
                    TextButton(
                      onPressed: onSecondary,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                      ),
                      child: Text(secondaryLabel),
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
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});
  final List<({String label, String value, String hint, IconData icon})>
  metrics;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 9,
    crossAxisSpacing: 9,
    childAspectRatio: 1.22,
    children: [
      for (final metric in metrics)
        MetricCard(
          label: metric.label,
          value: metric.value,
          hint: metric.hint,
          icon: metric.icon,
        ),
    ],
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});
  final List<({String label, IconData icon, VoidCallback onTap})> actions;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 2,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 9,
    crossAxisSpacing: 9,
    childAspectRatio: 1.42,
    children: [
      for (final action in actions)
        QuickActionTile(
          icon: action.icon,
          label: action.label,
          onTap: action.onTap,
        ),
    ],
  );
}

class _SetupChecklist extends StatelessWidget {
  const _SetupChecklist({
    required this.isVerified,
    required this.isAdmin,
    required this.isBuyer,
    required this.isCollector,
    required this.hasListing,
    required this.hasPoint,
    required this.hasExchange,
    required this.onOpenProfile,
    required this.onOpenMarketplace,
  });
  final bool isVerified;
  final bool isAdmin;
  final bool isBuyer;
  final bool isCollector;
  final bool hasListing;
  final bool hasPoint;
  final bool hasExchange;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenMarketplace;

  @override
  Widget build(BuildContext context) {
    final steps =
        <({String title, String body, bool done, VoidCallback? action})>[
          if (!isAdmin)
            (
              title: 'Complete your organization profile',
              body: 'Add contact details so partners can reach you.',
              done: true,
              action: onOpenProfile,
            ),
          if (!isAdmin)
            (
              title: 'Get verified',
              body: isVerified
                  ? 'Your organization is verified.'
                  : 'An admin is reviewing your organization.',
              done: isVerified,
              action: isVerified ? null : onOpenProfile,
            ),
          if (isBuyer)
            (
              title: 'Send your first request',
              body: hasExchange
                  ? 'You have already started exchanging.'
                  : 'Browse matched supply and send a purchase request.',
              done: hasExchange,
              action: onOpenMarketplace,
            )
          else if (isCollector)
            (
              title: 'Publish a collection point',
              body: hasPoint
                  ? 'Your points are on the network.'
                  : 'Pin a drop-off or pickup location anywhere in Tunisia.',
              done: hasPoint,
              action: onOpenMarketplace,
            )
          else if (!isAdmin)
            (
              title: 'Publish your first listing',
              body: hasListing
                  ? 'Your material listings are live.'
                  : 'Tell buyers what is available and when.',
              done: hasListing,
              action: onOpenMarketplace,
            ),
        ];
    if (steps.isEmpty) return const SizedBox.shrink();
    final completed = steps.where((step) => step.done).length;
    return ClacCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Eyebrow('SETUP CHECKLIST'),
              const Spacer(),
              Text(
                '$completed/${steps.length}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: steps.isEmpty ? 0 : completed / steps.length,
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          for (final step in steps)
            InkWell(
              onTap: step.action,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      step.done
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 19,
                      color: step.done
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  decoration: step.done
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                          ),
                          Text(
                            step.body,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (step.action != null && !step.done)
                      const Icon(Icons.arrow_forward, size: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = item['status']?.toString() ?? 'pending';
    final title = item['generator_name']?.toString().isNotEmpty == true
        ? item['generator_name'].toString()
        : item['processor_name']?.toString().isNotEmpty == true
        ? item['processor_name'].toString()
        : 'Material exchange';
    final created = DateTime.tryParse(item['created_at']?.toString() ?? '');
    return ClacCard(
      onTap: onTap,
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.swap_horiz,
              size: 19,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatValue(item['amount_kg'])} kg · ${materialLabel(item['waste_type'])}${created == null ? '' : ' · ${relativeTime(created)}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          StatusPill(status, icon: false),
        ],
      ),
    );
  }
}

class _NetworkPulse extends StatelessWidget {
  const _NetworkPulse({required this.stats, required this.onOpen});
  final Map<String, dynamic> stats;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => ClacCard(
    onTap: onOpen,
    color: Theme.of(context).colorScheme.primaryContainer.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? .30 : .55,
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.public,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 7),
            Text(
              'Tunisia network',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward, size: 17),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _PulseStat(label: 'Sellers', value: stats['generators']),
            _PulseStat(label: 'Buyers', value: stats['processors']),
            _PulseStat(label: 'Exchanges', value: stats['transactions']),
          ],
        ),
      ],
    ),
  );
}

class _PulseStat extends StatelessWidget {
  const _PulseStat({required this.label, required this.value});
  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatValue(value),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontFamily: 'serif'),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
    children: const [
      Row(
        children: [
          SkeletonBox(width: 42, height: 42, radius: 21),
          SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 150, height: 13),
              SizedBox(height: 7),
              SkeletonBox(width: 90, height: 9),
            ],
          ),
        ],
      ),
      SizedBox(height: 18),
      SkeletonBox(height: 210, radius: 20),
      SizedBox(height: 22),
      SkeletonBox(width: 90, height: 10),
      SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: SkeletonBox(height: 112, radius: 14)),
          SizedBox(width: 9),
          Expanded(child: SkeletonBox(height: 112, radius: 14)),
        ],
      ),
      SizedBox(height: 9),
      Row(
        children: [
          Expanded(child: SkeletonBox(height: 112, radius: 14)),
          SizedBox(width: 9),
          Expanded(child: SkeletonBox(height: 112, radius: 14)),
        ],
      ),
      SizedBox(height: 22),
      SkeletonBox(width: 110, height: 10),
      SizedBox(height: 10),
      SkeletonBox(height: 160, radius: 14),
    ],
  );
}

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({required this.user, required this.api, super.key});
  final Map<String, dynamic> user;
  final ApiClient api;

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  late Future<List<dynamic>> future;
  bool get isBuyer => widget.user['role'] == 'processor';
  final Set<String> savedIds = {};
  final Set<String> compareIds = {};
  final Set<String> matchingIds = {};
  final Map<String, List<dynamic>> buyerMatches = {};
  final Map<String, String> matchErrors = {};
  final TextEditingController searchController = TextEditingController();
  String? expandedMatchId;
  String query = '';
  String selectedMaterial = 'all';
  String selectedRegion = 'all';
  String sortBy = 'fit';
  String minimumVolume = '';
  bool savedOnly = false;

  String get savedKey =>
      'clac_saved_sources_${widget.user['id'] ?? widget.user['user_id'] ?? widget.user['email'] ?? 'guest'}';

  @override
  void initState() {
    super.initState();
    future = isBuyer ? widget.api.generators() : widget.api.myGenerators();
    _restoreSaved();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _restoreSaved() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => savedIds.addAll(prefs.getStringList(savedKey) ?? []));
    }
  }

  Future<void> _toggleSaved(String id) async {
    setState(
      () => savedIds.contains(id) ? savedIds.remove(id) : savedIds.add(id),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(savedKey, savedIds.toList());
  }

  void _toggleCompare(String id) {
    if (!compareIds.contains(id) && compareIds.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compare up to three supply sources at once.'),
        ),
      );
      return;
    }
    setState(
      () =>
          compareIds.contains(id) ? compareIds.remove(id) : compareIds.add(id),
    );
  }

  Future<void> _findBuyers(Map<String, dynamic> item) async {
    final id = item['id'].toString();
    if (expandedMatchId == id) {
      setState(() => expandedMatchId = null);
      return;
    }
    setState(() {
      expandedMatchId = id;
      matchingIds.add(id);
      matchErrors.remove(id);
      buyerMatches.remove(id);
    });
    try {
      final response = await widget.api.matchGenerator(
        id,
        amountKg: num.tryParse(item['avg_monthly_volume_kg']?.toString() ?? ''),
      );
      if (mounted) {
        setState(
          () =>
              buyerMatches[id] = List<dynamic>.from(response['matches'] ?? []),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => matchErrors[id] = error.toString().replaceFirst(
            'Exception: ',
            '',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => matchingIds.remove(id));
    }
  }

  double? _distance(Map<String, dynamic> item) {
    final home = regionCoordinates[widget.user['gouvernorat']?.toString()];
    final target = regionCoordinates[item['gouvernorat']?.toString()];
    final lat1 = double.tryParse(item['lat']?.toString() ?? '') ?? target?.$1;
    final lng1 = double.tryParse(item['lng']?.toString() ?? '') ?? target?.$2;
    if (home == null || lat1 == null || lng1 == null) return null;
    const earthKm = 6371.0;
    final dLat = (lat1 - home.$1) * math.pi / 180;
    final dLng = (lng1 - home.$2) * math.pi / 180;
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(home.$1 * math.pi / 180) *
            math.cos(lat1 * math.pi / 180) *
            math.pow(math.sin(dLng / 2), 2);
    return earthKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  void reload() => setState(
    () =>
        future = isBuyer ? widget.api.generators() : widget.api.myGenerators(),
  );

  Future<void> showListingForm() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SellerListingSheet(api: widget.api, user: widget.user),
    );
    if (result == true) reload();
  }

  Future<void> showPurchaseForm(Map<String, dynamic> generator) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => PurchaseSheet(
        api: widget.api,
        user: widget.user,
        generator: generator,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: future,
    builder: (context, snapshot) {
      final sourceItems = snapshot.data ?? [];
      final accepted = (widget.user['accepts_waste_types'] as List? ?? [])
          .map((value) => value.toString())
          .toSet();
      final materialOptions =
          sourceItems
              .expand((raw) => (raw['available_waste_types'] as List? ?? []))
              .map((value) => value.toString())
              .toSet()
              .toList()
            ..sort();
      final regions =
          sourceItems
              .map((raw) => raw['gouvernorat']?.toString())
              .whereType<String>()
              .toSet()
              .toList()
            ..sort();
      final capacity =
          double.tryParse(
            widget.user['max_capacity_kg_per_month']?.toString() ?? '',
          ) ??
          0;
      final maxSupplyVolume = sourceItems.fold<double>(
        0,
        (maximum, raw) => math
            .max(
              maximum,
              double.tryParse(raw['avg_monthly_volume_kg']?.toString() ?? '') ??
                  0,
            )
            .toDouble(),
      );
      final ranked = sourceItems.map((raw) {
        final item = Map<String, dynamic>.from(raw as Map);
        final types = (item['available_waste_types'] as List? ?? [])
            .map((v) => v.toString())
            .toList();
        final overlap = types.where(accepted.contains).toList();
        final compatibility = accepted.isEmpty
            ? .7
            : overlap.length / accepted.length;
        final distance = _distance(item);
        final distanceFit = distance == null ? .65 : 1 / (1 + distance / 250);
        final volume =
            double.tryParse(item['avg_monthly_volume_kg']?.toString() ?? '') ??
            0;
        final volumeFit = capacity > 0
            ? (volume / capacity).clamp(0, 1)
            : (maxSupplyVolume > 0
                  ? (volume / maxSupplyVolume).clamp(0, 1)
                  : .7);
        final fit =
            ((compatibility * .58 + distanceFit * .25 + volumeFit * .17) * 100)
                .round();
        return {
          ...item,
          '_types': types,
          '_overlap': overlap,
          '_distanceKm': distance,
          '_fitScore': fit,
        };
      }).toList();
      final items = ranked
          .where(
            (item) =>
                (!isBuyer ||
                    accepted.isEmpty ||
                    (item['_overlap'] as List).isNotEmpty) &&
                (selectedMaterial == 'all' ||
                    (item['_types'] as List).contains(selectedMaterial)) &&
                (selectedRegion == 'all' ||
                    item['gouvernorat'] == selectedRegion) &&
                (double.tryParse(
                          item['avg_monthly_volume_kg']?.toString() ?? '',
                        ) ??
                        0) >=
                    (double.tryParse(minimumVolume) ?? 0) &&
                (!savedOnly || savedIds.contains(item['id'].toString())) &&
                '${item['name']} ${item['gouvernorat']} ${(item['_types'] as List).join(' ')}'
                    .toLowerCase()
                    .contains(query.toLowerCase()),
          )
          .toList();
      if (isBuyer) {
        items.sort((a, b) {
          if (sortBy == 'volume') {
            return (double.tryParse(
                      b['avg_monthly_volume_kg']?.toString() ?? '',
                    ) ??
                    0)
                .compareTo(
                  double.tryParse(
                        a['avg_monthly_volume_kg']?.toString() ?? '',
                      ) ??
                      0,
                );
          }
          if (sortBy == 'distance' &&
              a['_distanceKm'] != null &&
              b['_distanceKm'] != null) {
            return (a['_distanceKm'] as double).compareTo(
              b['_distanceKm'] as double,
            );
          }
          return (b['_fitScore'] as int).compareTo(a['_fitScore'] as int);
        });
      }
      final compareItems = ranked
          .where((item) => compareIds.contains(item['id'].toString()))
          .toList();
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 19, 18, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(
                    isBuyer ? 'MATERIAL MARKETPLACE' : 'SELLER WORKSPACE',
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isBuyer ? 'Available materials' : 'My materials',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isBuyer
                        ? 'Supply matched to what you accept.'
                        : 'Listings owned by your organization.',
                    style: const TextStyle(color: muted),
                  ),
                  if (isBuyer) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${items.length} potential source${items.length == 1 ? '' : 's'} · fit weighs material overlap, location, and supply volume.',
                      style: const TextStyle(color: muted, fontSize: 10),
                    ),
                    const SizedBox(height: 13),
                    TextField(
                      controller: searchController,
                      onChanged: (value) => setState(() => query = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search suppliers, materials, or regions',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 4,
                      children: [
                        ChoiceChip(
                          label: const Text('All materials'),
                          selected: selectedMaterial == 'all',
                          onSelected: (_) =>
                              setState(() => selectedMaterial = 'all'),
                        ),
                        ...materialOptions.map(
                          (type) => ChoiceChip(
                            label: Text(materialLabel(type)),
                            selected: selectedMaterial == type,
                            onSelected: (_) =>
                                setState(() => selectedMaterial = type),
                          ),
                        ),
                        FilterChip(
                          label: Text('Saved (${savedIds.length})'),
                          selected: savedOnly,
                          avatar: const Icon(Icons.bookmark_outline, size: 16),
                          onSelected: (value) =>
                              setState(() => savedOnly = value),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedRegion,
                            decoration: const InputDecoration(
                              labelText: 'Governorate',
                              isDense: true,
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('All regions'),
                              ),
                              ...regions.map(
                                (g) =>
                                    DropdownMenuItem(value: g, child: Text(g)),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => selectedRegion = value ?? 'all'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: sortBy,
                            decoration: const InputDecoration(
                              labelText: 'Rank by',
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'fit',
                                child: Text('Best fit'),
                              ),
                              DropdownMenuItem(
                                value: 'volume',
                                child: Text('Largest supply'),
                              ),
                              DropdownMenuItem(
                                value: 'distance',
                                child: Text('Nearest'),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => sortBy = value ?? 'fit'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (value) =>
                          setState(() => minimumVolume = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.scale_outlined),
                        labelText: 'Minimum monthly supply (kg)',
                        isDense: true,
                      ),
                    ),
                  ],
                  if (!isBuyer) ...[
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: showListingForm,
                      icon: const Icon(Icons.add),
                      label: const Text('List materials'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isBuyer && compareItems.isNotEmpty)
            SliverToBoxAdapter(
              child: Card(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                color: const Color(0xffedf5ef),
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.compare_arrows, color: pine),
                          const SizedBox(width: 7),
                          const Expanded(
                            child: Text(
                              'Source comparison',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(compareIds.clear),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                      for (final item in compareItems)
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item['name']?.toString() ?? 'Source',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${item['_fitScore']}% fit · ${formatValue(item['avg_monthly_volume_kg'])} kg/mo',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    _toggleCompare(item['id'].toString()),
                                icon: const Icon(Icons.close, size: 17),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          if (snapshot.hasError)
            SliverFillRemaining(
              child: ErrorState(
                message: snapshot.error.toString(),
                onRetry: reload,
              ),
            )
          else if (!snapshot.hasData)
            const SliverFillRemaining(
              child: SkeletonList(count: 5, itemHeight: 120),
            )
          else if (items.isEmpty)
            SliverFillRemaining(
              child: EmptyStateMobile(
                title: isBuyer
                    ? 'No matching supply yet'
                    : 'No materials listed',
                body: isBuyer
                    ? 'Clear a sourcing filter or lower the minimum supply volume.'
                    : 'Publish your first material listing to get started.',
                action: isBuyer
                    ? TextButton.icon(
                        onPressed: () => setState(() {
                          query = '';
                          searchController.clear();
                          selectedMaterial = 'all';
                          selectedRegion = 'all';
                          minimumVolume = '';
                          savedOnly = false;
                        }),
                        icon: const Icon(Icons.filter_alt_off),
                        label: const Text('Clear sourcing filters'),
                      )
                    : FilledButton.icon(
                        onPressed: showListingForm,
                        icon: const Icon(Icons.add),
                        label: const Text('List materials'),
                      ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              sliver: SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 9),
                itemBuilder: (context, index) {
                  final item = Map<String, dynamic>.from(items[index] as Map);
                  final itemId = item['id'].toString();
                  final types = (item['available_waste_types'] as List? ?? [])
                      .map((value) => materialLabel(value.toString()))
                      .join(' · ');
                  return MaterialListingCard(
                    item: item,
                    types: types,
                    isBuyer: isBuyer,
                    onRequest: () => showPurchaseForm(item),
                    fitScore: item['_fitScore'] as int?,
                    distanceKm: item['_distanceKm'] as double?,
                    isSaved: savedIds.contains(itemId),
                    onToggleSaved: () => _toggleSaved(itemId),
                    isCompared: compareIds.contains(itemId),
                    onToggleCompare: () => _toggleCompare(itemId),
                    onFindBuyers: isBuyer ? null : () => _findBuyers(item),
                    matching: matchingIds.contains(itemId),
                    buyerMatches: buyerMatches[itemId] ?? const [],
                    matchError: matchErrors[itemId],
                    matchesExpanded: expandedMatchId == itemId,
                  );
                },
              ),
            ),
        ],
      );
    },
  );
}

class SellerListingSheet extends StatefulWidget {
  const SellerListingSheet({required this.api, required this.user, super.key});
  final ApiClient api;
  final Map<String, dynamic> user;

  @override
  State<SellerListingSheet> createState() => _SellerListingSheetState();
}

class _SellerListingSheetState extends State<SellerListingSheet> {
  final formKey = GlobalKey<FormState>();
  final title = TextEditingController();
  final description = TextEditingController();
  final condition = TextEditingController();
  final packaging = TextEditingController();
  final price = TextEditingController();
  final minimumOrder = TextEditingController();
  final photoUrl = TextEditingController();
  final volume = TextEditingController();
  final latitude = TextEditingController();
  final longitude = TextEditingController();
  final selected = <String>{};
  String region = '';
  DateTime? availableUntil;
  bool coordinatesEdited = false;
  bool saving = false;
  String? error;
  String get _draftKey =>
      'clac_listing_draft_${widget.user['id'] ?? widget.user['email'] ?? 'member'}';

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    title.text = prefs.getString('${_draftKey}_name') ?? '';
    description.text = prefs.getString('${_draftKey}_description') ?? '';
    condition.text = prefs.getString('${_draftKey}_condition') ?? '';
    packaging.text = prefs.getString('${_draftKey}_packaging') ?? '';
    price.text = prefs.getString('${_draftKey}_price') ?? '';
    minimumOrder.text = prefs.getString('${_draftKey}_minimum_order') ?? '';
    photoUrl.text = prefs.getString('${_draftKey}_photo_url') ?? '';
    volume.text = prefs.getString('${_draftKey}_volume') ?? '';
    availableUntil = DateTime.tryParse(
      prefs.getString('${_draftKey}_availability') ?? '',
    );
    region = prefs.getString('${_draftKey}_region') ?? '';
    latitude.text = prefs.getString('${_draftKey}_lat') ?? '';
    longitude.text = prefs.getString('${_draftKey}_lng') ?? '';
    coordinatesEdited = prefs.getBool('${_draftKey}_exact') ?? false;
    selected.addAll(prefs.getStringList('${_draftKey}_materials') ?? const []);
    setState(() {});
  }

  Future<void> _saveDraft({bool showMessage = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${_draftKey}_name', title.text.trim());
    await prefs.setString('${_draftKey}_description', description.text.trim());
    await prefs.setString('${_draftKey}_condition', condition.text.trim());
    await prefs.setString('${_draftKey}_packaging', packaging.text.trim());
    await prefs.setString('${_draftKey}_price', price.text.trim());
    await prefs.setString(
      '${_draftKey}_minimum_order',
      minimumOrder.text.trim(),
    );
    await prefs.setString('${_draftKey}_photo_url', photoUrl.text.trim());
    await prefs.setString('${_draftKey}_volume', volume.text.trim());
    await prefs.setString(
      '${_draftKey}_availability',
      availableUntil?.toIso8601String() ?? '',
    );
    await prefs.setString('${_draftKey}_region', region);
    await prefs.setString('${_draftKey}_lat', latitude.text.trim());
    await prefs.setString('${_draftKey}_lng', longitude.text.trim());
    await prefs.setBool('${_draftKey}_exact', coordinatesEdited);
    await prefs.setStringList('${_draftKey}_materials', selected.toList());
    if (showMessage && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.clac('Listing draft saved on this device.')),
        ),
      );
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    for (final suffix in [
      'name',
      'description',
      'condition',
      'packaging',
      'price',
      'minimum_order',
      'photo_url',
      'volume',
      'availability',
      'region',
      'lat',
      'lng',
      'exact',
      'materials',
    ]) {
      await prefs.remove('${_draftKey}_$suffix');
    }
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    condition.dispose();
    packaging.dispose();
    price.dispose();
    minimumOrder.dispose();
    photoUrl.dispose();
    volume.dispose();
    latitude.dispose();
    longitude.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    if (selected.isEmpty) {
      setState(() => error = 'Choose at least one material.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final coordinates =
        regionCoordinates[region] ?? regionCoordinates['Tunis']!;
    final lat = double.tryParse(latitude.text) ?? coordinates.$1;
    final lng = double.tryParse(longitude.text) ?? coordinates.$2;
    if (lat < 30 || lat > 38.5 || lng < 7 || lng > 12.5) {
      setState(() => error = 'Coordinates must be inside Tunisia.');
      setState(() => saving = false);
      return;
    }
    try {
      await widget.api.createListing({
        'name': title.text.trim(),
        'type': 'other',
        'description': description.text.trim(),
        'material_condition': condition.text.trim(),
        'packaging_details': packaging.text.trim(),
        'price_per_kg': price.text.trim().isEmpty
            ? null
            : double.tryParse(price.text.trim()),
        'minimum_order_kg': minimumOrder.text.trim().isEmpty
            ? null
            : double.tryParse(minimumOrder.text.trim()),
        'available_until': availableUntil?.toIso8601String().split('T').first,
        'photo_url': photoUrl.text.trim().isEmpty ? null : photoUrl.text.trim(),
        'lat': lat,
        'lng': lng,
        'is_location_approximate': !coordinatesEdited,
        'available_waste_types': selected.toList(),
        'avg_monthly_volume_kg': int.parse(volume.text),
        'seasonal': false,
        'gouvernorat': region,
        'contact_phone': '',
        'contact_email': widget.user['email'],
      });
      await _clearDraft();
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      await _saveDraft(showMessage: false);
      if (mounted) {
        setState(
          () => error = exception.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: formKey,
      child: ListView(
        shrinkWrap: true,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDE3DC),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('List materials', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          if (error != null) ErrorBanner(error!),
          TextFormField(
            controller: title,
            decoration: const InputDecoration(labelText: 'Listing name'),
            validator: requiredText,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: description,
            minLines: 2,
            maxLines: 4,
            maxLength: 4000,
            decoration: const InputDecoration(
              labelText: 'Description and material specifications',
              hintText: 'Source, quality, moisture, contamination, or use case',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: condition,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Material condition',
              hintText: 'Clean, sorted, dry, mixed…',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: packaging,
            maxLength: 300,
            decoration: const InputDecoration(
              labelText: 'Packaging and loading',
              hintText: 'Bulk, bags, pallets; loading equipment available',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Asking price (TND/kg, optional)',
              helperText: 'Leave blank to negotiate directly.',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final amount = double.tryParse(value.trim());
              return amount == null || amount < 0
                  ? 'Enter a valid price or leave it blank.'
                  : null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: minimumOrder,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Minimum order (kg, optional)',
              helperText: 'Buyers will not be able to request less than this.',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final amount = double.tryParse(value.trim());
              final monthly = double.tryParse(volume.text.trim()) ?? 0;
              return amount == null || amount <= 0 || amount > monthly
                  ? 'Enter a positive value within monthly volume.'
                  : null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: photoUrl,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Photo URL (optional)',
              helperText: 'Use a public HTTPS image link.',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return null;
              final uri = Uri.tryParse(value.trim());
              return uri?.scheme == 'https' && uri?.host.isNotEmpty == true
                  ? null
                  : 'Enter a valid HTTPS image URL.';
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: const Text('Available until'),
            subtitle: Text(
              availableUntil == null
                  ? 'No end date set'
                  : MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(availableUntil!),
            ),
            trailing: Wrap(
              children: [
                if (availableUntil != null)
                  IconButton(
                    tooltip: 'Clear availability date',
                    onPressed: () => setState(() => availableUntil = null),
                    icon: const Icon(Icons.close),
                  ),
                IconButton(
                  tooltip: 'Choose availability end date',
                  onPressed: () async {
                    final today = DateUtils.dateOnly(DateTime.now());
                    final selectedDate = await showDatePicker(
                      context: context,
                      initialDate: availableUntil ?? today,
                      firstDate: today,
                      lastDate: today.add(const Duration(days: 730)),
                    );
                    if (selectedDate != null && mounted) {
                      setState(() => availableUntil = selectedDate);
                    }
                  },
                  icon: const Icon(Icons.calendar_month_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey(region),
            initialValue: region.isEmpty ? null : region,
            decoration: const InputDecoration(labelText: 'Governorate'),
            items: governorates
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => setState(() {
              region = value ?? '';
              if (!coordinatesEdited && regionCoordinates[region] != null) {
                latitude.text = regionCoordinates[region]!.$1.toString();
                longitude.text = regionCoordinates[region]!.$2.toString();
              }
            }),
            validator: (value) => value == null ? 'Choose a governorate' : null,
          ),
          const SizedBox(height: 8),
          const Text(
            'Pin location (governorate center is approximate)',
            style: TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: latitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Latitude'),
                  onChanged: (_) => coordinatesEdited = true,
                  validator: _coordinateValidator,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: longitude,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Longitude'),
                  onChanged: (_) => coordinatesEdited = true,
                  validator: _coordinateValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: volume,
            decoration: const InputDecoration(labelText: 'Monthly volume (kg)'),
            keyboardType: TextInputType.number,
            validator: (value) => (int.tryParse(value ?? '') ?? 0) <= 0
                ? 'Enter a positive volume'
                : null,
          ),
          const SizedBox(height: 12),
          const Eyebrow('AVAILABLE MATERIALS'),
          Wrap(
            spacing: 7,
            children: materials.entries
                .map(
                  (entry) => FilterChip(
                    label: Text(entry.value),
                    selected: selected.contains(entry.key),
                    onSelected: (value) => setState(
                      () => value
                          ? selected.add(entry.key)
                          : selected.remove(entry.key),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _saveDraft,
            icon: const Icon(Icons.save_outlined),
            label: Text(context.clac('Save draft on this device')),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: saving ? null : submit,
            child: Text(saving ? 'Publishing…' : 'Publish listing'),
          ),
        ],
      ),
    ),
  );

  String? _coordinateValidator(String? value) =>
      double.tryParse(value ?? '') == null ? 'Enter a number' : null;
}

class PurchaseSheet extends StatefulWidget {
  const PurchaseSheet({
    required this.api,
    required this.user,
    required this.generator,
    super.key,
  });
  final ApiClient api;
  final Map<String, dynamic> user;
  final Map<String, dynamic> generator;

  @override
  State<PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<PurchaseSheet> {
  final amount = TextEditingController();
  final notes = TextEditingController();
  bool saving = false;
  String? error;
  String get draftKey =>
      'clac_purchase_draft_${widget.user['id'] ?? widget.user['email'] ?? 'member'}_${widget.generator['id']}';

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    amount.text = prefs.getString('${draftKey}_amount') ?? '';
    notes.text = prefs.getString('${draftKey}_notes') ?? '';
  }

  Future<void> _saveDraft({bool showMessage = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${draftKey}_amount', amount.text.trim());
    await prefs.setString('${draftKey}_notes', notes.text.trim());
    if (showMessage && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.clac('Purchase request draft saved on this device.'),
          ),
        ),
      );
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${draftKey}_amount');
    await prefs.remove('${draftKey}_notes');
  }

  @override
  void dispose() {
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final volume = int.tryParse(amount.text) ?? 0;
    if (volume <= 0) {
      setState(() => error = 'Enter a positive volume.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.api.createPurchase({
        'generatorId': widget.generator['id'],
        'processorId': widget.user['processor_id'],
        'amountKg': volume,
        'notes': notes.text,
      });
      await _clearDraft();
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      await _saveDraft(showMessage: false);
      if (mounted) {
        setState(
          () => error = exception.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      12,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: ListView(
      shrinkWrap: true,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDDE3DC),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Request ${widget.generator['name']}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 5),
        Text(
          '${widget.generator['gouvernorat']} · ${(widget.generator['available_waste_types'] as List? ?? []).map(materialLabel).join(' · ')}',
          style: const TextStyle(color: muted),
        ),
        const SizedBox(height: 14),
        if (error != null) ErrorBanner(error!),
        TextField(
          controller: amount,
          decoration: const InputDecoration(labelText: 'Requested volume (kg)'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: notes,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _saveDraft,
          icon: const Icon(Icons.save_outlined),
          label: Text(context.clac('Save request draft on this device')),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: saving ? null : submit,
          child: Text(saving ? 'Sending…' : 'Send purchase request'),
        ),
      ],
    ),
  );
}

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({required this.user, required this.api, super.key});
  final Map<String, dynamic> user;
  final ApiClient api;

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
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
  Widget build(BuildContext context) => FutureBuilder<List<dynamic>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return ErrorState(
          message: snapshot.error.toString(),
          onRetry: () => setState(() {
            future = widget.api.transactions();
          }),
        );
      }
      if (!snapshot.hasData) {
        return const SkeletonList(count: 5, padding: EdgeInsets.all(16));
      }
      final items = snapshot.data!;
      if (items.isEmpty) {
        return EmptyStateMobile(
          title: widget.user['role'] == 'processor'
              ? 'No purchase requests yet'
              : 'No requests for your listings',
          body: 'Requests related to your account will appear here.',
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
            return Card(
              color: Theme.of(context).cardTheme.color,
              elevation: 0,
              child: ListTile(
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TransactionDetailScreen(
                        user: widget.user,
                        api: widget.api,
                        transactionId: item['id'].toString(),
                      ),
                    ),
                  );
                  if (mounted) {
                    setState(() {
                      future = widget.api.transactions();
                    });
                  }
                },
                title: Text(
                  item['generator_name']?.toString() ?? 'Material request',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${materialLabel(item['waste_type'])} · ${formatValue(item['amount_kg'])} kg',
                ),
                trailing: StatusPill(item['status']?.toString() ?? 'pending'),
              ),
            );
          },
        ),
      );
    },
  );
}

class MaterialListingCard extends StatelessWidget {
  const MaterialListingCard({
    required this.item,
    required this.types,
    required this.isBuyer,
    required this.onRequest,
    this.fitScore,
    this.distanceKm,
    this.isSaved = false,
    this.onToggleSaved,
    this.isCompared = false,
    this.onToggleCompare,
    this.onFindBuyers,
    this.matching = false,
    this.buyerMatches = const [],
    this.matchError,
    this.matchesExpanded = false,
    super.key,
  });
  final Map<String, dynamic> item;
  final String types;
  final bool isBuyer;
  final VoidCallback onRequest;
  final int? fitScore;
  final double? distanceKm;
  final bool isSaved;
  final VoidCallback? onToggleSaved;
  final bool isCompared;
  final VoidCallback? onToggleCompare;
  final VoidCallback? onFindBuyers;
  final bool matching;
  final List<dynamic> buyerMatches;
  final String? matchError;
  final bool matchesExpanded;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).cardTheme.color,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(9),
      side: const BorderSide(color: Color(0xFFE1E6DF)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item['photo_url']?.toString().startsWith('https://') == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  item['photo_url'].toString(),
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 90,
                    color: const Color(0xffedf5ef),
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E5A43), Color(0xFF3A8A68)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.recycling,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name']?.toString() ?? 'Material source',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item['gouvernorat']?.toString() ?? 'Tunisia',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        if (item['owner_verified'] == true) ...[
                          const SizedBox(width: 4),
                          const Tooltip(
                            message: 'Verified organization',
                            child: Icon(Icons.verified, color: pine, size: 14),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isBuyer && fitScore != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F0E7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$fitScore% fit',
                    style: const TextStyle(
                      color: pine,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            types,
            style: const TextStyle(color: pine, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            '${formatValue(item['avg_monthly_volume_kg'])} kg available per month',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          if (item['description']?.toString().trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                item['description'].toString(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          if (item['material_condition']?.toString().isNotEmpty == true ||
              item['packaging_details']?.toString().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                [
                  if (item['material_condition']?.toString().isNotEmpty == true)
                    'Condition: ${item['material_condition']}',
                  if (item['packaging_details']?.toString().isNotEmpty == true)
                    'Packaging: ${item['packaging_details']}',
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ),
          if (item['price_per_kg'] != null || item['available_until'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (item['price_per_kg'] != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        'TND ${formatValue(item['price_per_kg'])}/kg',
                      ),
                    ),
                  if (item['minimum_order_kg'] != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                      label: Text(
                        'Minimum ${formatValue(item['minimum_order_kg'])} kg',
                      ),
                    ),
                  if (item['available_until'] != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.event_outlined, size: 16),
                      label: Text('Until ${item['available_until']}'),
                    ),
                ],
              ),
            ),
          if (isBuyer && fitScore != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: fitScore!.clamp(0, 100) / 100,
                      minHeight: 6,
                      color: pine,
                      backgroundColor: const Color(0xffe7eee8),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  '$fitScore% fit',
                  style: const TextStyle(
                    color: pine,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            if (distanceKm != null)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  'About ${distanceKm!.round()} km from your governorate',
                  style: const TextStyle(color: muted, fontSize: 10),
                ),
              ),
          ],
          if (isBuyer) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 7,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: onToggleSaved,
                  icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_outline),
                  label: Text(isSaved ? 'Saved' : 'Save'),
                ),
                OutlinedButton.icon(
                  onPressed: onToggleCompare,
                  icon: Icon(isCompared ? Icons.check : Icons.compare_arrows),
                  label: Text(isCompared ? 'Compared' : 'Compare'),
                ),
                FilledButton.icon(
                  onPressed: onRequest,
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Request'),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: matching ? null : onFindBuyers,
              icon: matching
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(
                matchesExpanded ? 'Hide buyer matches' : 'Find best buyers',
              ),
            ),
            if (matchesExpanded && matchError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  matchError!,
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
              ),
            if (matchesExpanded && buyerMatches.isNotEmpty) ...[
              const Divider(height: 20),
              for (final raw in buyerMatches.take(3))
                Builder(
                  builder: (context) {
                    final buyer = Map<String, dynamic>.from(raw as Map);
                    final impact = buyer['estimatedImpact'] is Map
                        ? Map<String, dynamic>.from(
                            buyer['estimatedImpact'] as Map,
                          )
                        : <String, dynamic>{};
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: CircleAvatar(
                        radius: 17,
                        backgroundColor: const Color(0xffedf5ef),
                        child: Text(
                          '${((double.tryParse(buyer['score']?.toString() ?? '') ?? 0) * 100).round()}%',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: pine,
                          ),
                        ),
                      ),
                      title: Text(
                        buyer['name']?.toString() ?? 'Buyer',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${buyer['gouvernorat'] ?? 'Tunisia'} · ${buyer['distanceKm'] ?? '—'} km · ${formatValue(impact['kgCO2eSaved'])} kg CO₂e potential',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
            ] else if (matchesExpanded && !matching && matchError == null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'No compatible buyers found for this listing yet.',
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}
