import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:clac_mobile/core/app_theme.dart';
import 'package:clac_mobile/shared/widgets.dart';

class CollectionPointDetailScreen extends StatelessWidget {
  const CollectionPointDetailScreen({
    required this.item,
    this.kind,
    this.onEdit,
    super.key,
  });

  final Map<String, dynamic> item;
  final String? kind;
  final VoidCallback? onEdit;

  String get _kind {
    final explicit = kind ?? item['_kind']?.toString();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    if (item['point_type'] != null) return 'Collection point';
    if (item['accepts_waste_types'] != null) return 'Recovery partner';
    return 'Seller';
  }

  bool get _isCollection => _kind.toLowerCase().contains('collection point');

  bool get _isPending =>
      _isCollection &&
      item['is_verified'] != true &&
      item['is_active'] != false;

  bool get _isRejected => _isCollection && item['is_active'] == false;

  String get _status {
    if (_isRejected) return 'Needs changes';
    if (_isPending) return 'Pending review';
    if (_isCollection) return 'Verified';
    return 'Network member';
  }

  String get _typeLabel => switch (item['point_type']) {
    'pickup_site' => 'Pickup site',
    'recycling_center' => 'Recycling center',
    _ => _isCollection ? 'Drop-off point' : _kind,
  };

  List<String> get _materials => [
    for (final value
        in (item['accepts_waste_types'] ??
                item['available_waste_types'] ??
                const [])
            as List)
      materialLabel(value),
  ];

  String? get _phone {
    final value = item['contact_phone'] ?? item['phone'];
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  String? get _ownerName {
    for (final key in ['owner_company', 'owner_name', 'submitter_name']) {
      final value = item[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  String? get _ownerRole {
    final value = item['owner_role']?.toString();
    return switch (value) {
      'collector' => 'Collection specialist',
      'processor' => 'Recovery partner',
      'generator' => 'Material seller',
      _ => null,
    };
  }

  Future<void> _openDirections(BuildContext context) async {
    final lat = double.tryParse(item['lat']?.toString() ?? '');
    final lng = double.tryParse(item['lng']?.toString() ?? '');
    if (lat == null || lng == null) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$lat,$lng',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open directions on this device.'),
        ),
      );
    }
  }

  Future<void> _call(BuildContext context) async {
    final phone = _phone;
    if (phone == null) return;
    if (!await launchUrl(Uri(scheme: 'tel', path: phone)) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start a call on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final address = item['address']?.toString().trim() ?? '';
    final description = item['description']?.toString().trim() ?? '';
    final hours = item['opening_hours']?.toString().trim() ?? '';
    final region = item['gouvernorat']?.toString() ?? 'Tunisia';
    final createdAt = DateTime.tryParse(item['created_at']?.toString() ?? '');
    final updatedAt = DateTime.tryParse(item['updated_at']?.toString() ?? '');
    final reviewNote = item['review_note']?.toString().trim() ?? '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 218,
            backgroundColor: pineDark,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            actionsIconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (onEdit != null)
                IconButton(
                  tooltip: 'Edit',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF123528), Color(0xFF2C7658)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -50,
                      top: 10,
                      child: Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: .06),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 22,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _typeLabel.toUpperCase(),
                            style: const TextStyle(
                              color: Color(0xFFF5C77C),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            item['name']?.toString() ?? 'Network location',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'serif',
                              color: Colors.white,
                              fontSize: 27,
                              height: 1.12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 14,
                                color: Color(0xFFD2E5D8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                region,
                                style: const TextStyle(
                                  color: Color(0xFFD2E5D8),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: .13),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _status,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
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
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_isPending) ...[
                  const InfoBanner(
                    title: 'Waiting for admin review',
                    body:
                        'This point is private to its owner until an administrator verifies it. You can still edit the details.',
                    tone: BannerTone.warning,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_isRejected) ...[
                  InfoBanner(
                    title: 'This point needs changes',
                    body: reviewNote.isEmpty
                        ? 'The submission was rejected. Edit it and submit it again for review.'
                        : reviewNote,
                    tone: BannerTone.danger,
                    actionLabel: onEdit == null ? null : 'Edit and resubmit',
                    onAction: onEdit,
                  ),
                  const SizedBox(height: 12),
                ],
                if (_isCollection)
                  _StatusTimeline(
                    pending: _isPending,
                    rejected: _isRejected,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                  ),
                if (_isCollection) const SizedBox(height: 14),
                if (description.isNotEmpty) ...[
                  ClacCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('ABOUT THIS LOCATION'),
                        const SizedBox(height: 8),
                        Text(description, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                ClacCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Eyebrow('ACCEPTED MATERIALS'),
                      const SizedBox(height: 10),
                      if (_materials.isEmpty)
                        Text(
                          'Materials will be confirmed with the operator.',
                          style: theme.textTheme.bodySmall,
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final material in _materials)
                              Chip(
                                label: Text(material),
                                avatar: const Icon(Icons.recycling, size: 14),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ClacCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      if (address.isNotEmpty)
                        ListTile(
                          leading: const Icon(Icons.map_outlined, size: 20),
                          title: Text(address),
                          subtitle: Text(region),
                        ),
                      if (hours.isNotEmpty)
                        ListTile(
                          leading: const Icon(
                            Icons.schedule_outlined,
                            size: 20,
                          ),
                          title: Text(hours),
                          subtitle: const Text('Opening hours'),
                        ),
                      if (_phone != null)
                        ListTile(
                          onTap: () => _call(context),
                          leading: const Icon(Icons.call_outlined, size: 20),
                          title: Text(_phone!),
                          subtitle: const Text('Contact this location'),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      ListTile(
                        leading: const Icon(
                          Icons.my_location_outlined,
                          size: 20,
                        ),
                        title: Text(
                          '${formatValue(item['lat'])}, ${formatValue(item['lng'])}',
                        ),
                        subtitle: Text(
                          item['is_location_approximate'] == true
                              ? 'Approximate governorate location'
                              : 'Pinned location',
                        ),
                        trailing: const Icon(Icons.directions_outlined),
                        onTap: () => _openDirections(context),
                      ),
                    ],
                  ),
                ),
                if (_ownerName != null) ...[
                  const SizedBox(height: 10),
                  ClacCard(
                    child: Row(
                      children: [
                        InitialsAvatar(name: _ownerName!, size: 40),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _ownerName!,
                                style: theme.textTheme.titleSmall,
                              ),
                              Text(
                                _ownerRole == null
                                    ? 'Point operator'
                                    : '${_ownerRole!} · Point operator',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const StatusPill('Operator', icon: false),
                      ],
                    ),
                  ),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Added ${relativeTime(createdAt)}${updatedAt == null ? '' : ' · updated ${relativeTime(updatedAt)}'}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              if (_phone != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _call(context),
                    icon: const Icon(Icons.call_outlined, size: 17),
                    label: const Text('Call'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => _openDirections(context),
                  icon: const Icon(Icons.directions_outlined, size: 17),
                  label: const Text('Get directions'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({
    required this.pending,
    required this.rejected,
    this.createdAt,
    this.updatedAt,
  });
  final bool pending;
  final bool rejected;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final steps = rejected
        ? [
            (title: 'Submitted', body: 'Point details received.', done: true),
            (
              title: 'Changes requested',
              body: 'An admin left feedback on this point.',
              done: true,
            ),
            (
              title: 'Resubmit for review',
              body: 'Edit the point to return it to the queue.',
              done: false,
            ),
          ]
        : pending
        ? [
            (title: 'Submitted', body: 'Point details received.', done: true),
            (
              title: 'Admin review',
              body: 'An administrator is checking the location.',
              done: true,
            ),
            (
              title: 'Published',
              body: 'The point appears on the public network map.',
              done: false,
            ),
          ]
        : [
            (title: 'Submitted', body: 'Point details received.', done: true),
            (title: 'Admin review', body: 'Location approved.', done: true),
            (
              title: 'Published',
              body: 'Visible to the whole CLAC network.',
              done: true,
            ),
          ];
    return ClacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Eyebrow('STATUS'),
          const SizedBox(height: 10),
          if (createdAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Submitted ${relativeTime(createdAt)}${updatedAt == null ? '' : ' · updated ${relativeTime(updatedAt)}'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          for (var i = 0; i < steps.length; i++)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: steps[i].done
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: steps[i].done
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                            width: 1.5,
                          ),
                        ),
                        child: steps[i].done
                            ? const Icon(
                                Icons.check,
                                size: 11,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      if (i != steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 1.5,
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            color: steps[i].done
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: .35)
                                : Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: i == steps.length - 1 ? 0 : 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            steps[i].title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: steps[i].done
                                      ? null
                                      : Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          Text(
                            steps[i].body,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
