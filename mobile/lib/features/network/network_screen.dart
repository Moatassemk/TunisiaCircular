import 'dart:math' as math;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:clac_mobile/core/api_client.dart';
import 'package:clac_mobile/shared/strings.dart';
import 'package:clac_mobile/shared/map_marker_clusters.dart';
import 'package:clac_mobile/core/map_tile_config.dart';
import 'package:clac_mobile/features/network/collection_point_detail_screen.dart';
import 'package:clac_mobile/shared/widgets.dart'
    show
        governorates,
        regionCoordinates,
        materials,
        materialLabel,
        ErrorState,
        EmptyStateMobile,
        SkeletonList,
        ErrorBanner,
        InfoBanner,
        BannerTone,
        ClacCard,
        Eyebrow,
        StatusPill,
        showClacSuccessSheet;
import 'package:clac_mobile/core/osm_tile_web.dart'
    if (dart.library.io) 'package:clac_mobile/core/osm_tile.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({required this.api, required this.user, super.key});
  final ApiClient api;
  final Map<String, dynamic> user;
  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  late Future<List<Map<String, dynamic>>> future;
  String kind = 'all';
  String material = 'All materials';
  String query = '';
  Map<String, dynamic>? selected;
  final Set<String> _savedLocationIds = <String>{};
  bool _showMap = true;
  bool _savedOnly = false;
  Timer? searchDebounce;
  Timer? boundsDebounce;
  String mapBounds = '7,30,12.5,38.5';
  @override
  void initState() {
    super.initState();
    future = _load();
    _restoreSavedLocations();
  }

  String get _savedLocationsKey =>
      'clac_saved_locations_${widget.user['id'] ?? widget.user['email'] ?? 'member'}';

  Future<void> _restoreSavedLocations() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
      () => _savedLocationIds.addAll(
        prefs.getStringList(_savedLocationsKey) ?? const [],
      ),
    );
  }

  Future<void> _toggleSavedLocation(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return;
    setState(() {
      if (!_savedLocationIds.add(id)) _savedLocationIds.remove(id);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_savedLocationsKey, _savedLocationIds.toList());
  }

  bool get canManagePoints =>
      const {'generator', 'collector'}.contains(widget.user['role']);

  Future<void> _openDetails(Map<String, dynamic> item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CollectionPointDetailScreen(
          item: item,
          kind: item['_kind']?.toString(),
        ),
      ),
    );
  }

  Future<void> _showMyCollectionPoints() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.85,
        child: CollectionPointsView(
          api: widget.api,
          user: widget.user,
          onChanged: () {
            if (mounted) {
              setState(() {
                future = _load();
              });
            }
          },
        ),
      ),
    );
    if (mounted) {
      setState(() {
        future = _load();
      });
    }
  }

  Future<void> _openDirections(Map<String, dynamic> item) async {
    final lat = _coordinate(item['lat']);
    final lng = _coordinate(item['lng']);
    if (lat == null || lng == null) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$lat,$lng',
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open directions on this device.'),
        ),
      );
    }
  }

  Future<void> _callLocation(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start a call on this device.')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final results = await Future.wait([
      widget.api.networkDirectory(
        kind: kind,
        material: material,
        query: query,
        bounds: mapBounds,
      ),
      _loadOptional(widget.api.myCollectionPoints()),
    ]);
    final bounds = mapBounds.split(',').map(double.parse).toList();
    final pendingPoints = results[1].where((raw) {
      final point = Map<String, dynamic>.from(raw as Map);
      final lat = _coordinate(point['lat']);
      final lng = _coordinate(point['lng']);
      return point['is_verified'] != true &&
          point['is_active'] != false &&
          lat != null &&
          lng != null &&
          lng >= bounds[0] &&
          lat >= bounds[1] &&
          lng <= bounds[2] &&
          lat <= bounds[3];
    });
    return [
          ...results[0].map((e) => Map<String, dynamic>.from(e as Map)),
          ...pendingPoints.map(
            (e) => {
              ...Map<String, dynamic>.from(e as Map),
              '_kind': 'Collection point (pending review)',
            },
          ),
        ]
        .where(
          (e) => _coordinate(e['lat']) != null && _coordinate(e['lng']) != null,
        )
        .toList();
  }

  Future<List<dynamic>> _loadOptional(Future<List<dynamic>> request) async {
    try {
      return await request;
    } catch (_) {
      return const <dynamic>[];
    }
  }

  double? _coordinate(dynamic value) =>
      value == null ? null : double.tryParse(value.toString());

  void _changeFilter(void Function() change) => setState(() {
    change();
    future = _load();
  });

  @override
  void dispose() {
    searchDebounce?.cancel();
    boundsDebounce?.cancel();
    super.dispose();
  }

  void _updateMapBounds(String value) {
    boundsDebounce?.cancel();
    boundsDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || value == mapBounds) return;
      setState(() {
        mapBounds = value;
        future = _load();
      });
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snap) {
      if (snap.hasError) {
        return Center(
          child: TextButton.icon(
            onPressed: () => setState(() {
              future = _load();
            }),
            icon: const Icon(Icons.refresh),
            label: Text(context.clac('Could not load network. Retry')),
          ),
        );
      }
      if (!snap.hasData) {
        return const SkeletonList(count: 5, itemHeight: 105);
      }
      final items = snap.data!
          .where(
            (e) =>
                (kind == 'all' ||
                    e['_kind'] == kind ||
                    (kind == 'Collection point' &&
                        e['_kind'] == 'Collection point (pending review)')) &&
                (material == 'All materials' ||
                    ((e['available_waste_types'] ??
                                e['accepts_waste_types'] ??
                                const [])
                            as List)
                        .contains(material)) &&
                (!_savedOnly ||
                    _savedLocationIds.contains(e['id']?.toString())) &&
                '${e['name']} ${e['gouvernorat']} ${e['type']} ${e['address']}'
                    .toLowerCase()
                    .contains(query.toLowerCase()),
          )
          .toList();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.clac('Tunisia network'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (canManagePoints)
                      FilledButton.tonalIcon(
                        onPressed: _showMyCollectionPoints,
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: Text(context.clac('My points')),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  context.clac(
                    'Browse sellers, recovery partners, and verified collection points.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  onChanged: (v) {
                    setState(() => query = v);
                    searchDebounce?.cancel();
                    searchDebounce = Timer(
                      const Duration(milliseconds: 350),
                      () {
                        if (mounted) {
                          setState(() {
                            future = _load();
                          });
                        }
                      },
                    );
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: context.clac('Search name or governorate'),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    children:
                        [
                              'all',
                              'Seller',
                              'Recovery partner',
                              'Collection point',
                            ]
                            .map(
                              (v) => Padding(
                                padding: const EdgeInsets.only(right: 7),
                                child: ChoiceChip(
                                  label: Text(
                                    context.clac(v == 'all' ? 'All' : v),
                                  ),
                                  selected:
                                      (kind == 'all' && v == 'all') ||
                                      kind == v,
                                  onSelected: (_) =>
                                      _changeFilter(() => kind = v),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 5),
                DropdownButtonFormField<String>(
                  initialValue: material,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.recycling),
                    labelText: context.clac('Filter by material'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  items: ['All materials', ...materials.keys]
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(
                            context.clac(
                              v == 'All materials' ? v : materialLabel(v),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      _changeFilter(() => material = v ?? 'All materials'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Row(
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: true,
                      icon: const Icon(Icons.map_outlined),
                      label: Text(context.clac('Map')),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: const Icon(Icons.list_alt),
                      label: Text(context.clac('List')),
                    ),
                  ],
                  selected: {_showMap},
                  showSelectedIcon: false,
                  onSelectionChanged: (value) =>
                      setState(() => _showMap = value.first),
                ),
                const Spacer(),
                FilterChip(
                  avatar: const Icon(Icons.bookmark_outline, size: 17),
                  label: Text(context.clac('Saved')),
                  selected: _savedOnly,
                  onSelected: (value) => setState(() => _savedOnly = value),
                ),
              ],
            ),
          ),
          if (_showMap)
            SizedBox(
              height: 260,
              child: _TunisiaMap(
                items: items,
                selected: selected,
                onSelect: (e) => setState(() => selected = e),
                onBoundsChanged: _updateMapBounds,
              ),
            ),
          if (selected != null && items.any((e) => e['id'] == selected!['id']))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 2),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.28,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.place, color: Color(0xff236749)),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              selected!['name']?.toString() ?? 'Location',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (selected!['_kind'] == 'Collection point' ||
                              selected!['owner_verified'] == true)
                            StatusPill(
                              selected!['_kind'] == 'Collection point'
                                  ? (selected!['is_verified'] == true
                                        ? 'Verified'
                                        : 'Pending review')
                                  : 'Verified',
                            ),
                          IconButton(
                            tooltip: context.clac(
                              _savedLocationIds.contains(
                                    selected!['id']?.toString(),
                                  )
                                  ? 'Remove saved location'
                                  : 'Save location',
                            ),
                            onPressed: () => _toggleSavedLocation(selected!),
                            icon: Icon(
                              _savedLocationIds.contains(
                                    selected!['id']?.toString(),
                                  )
                                  ? Icons.bookmark
                                  : Icons.bookmark_outline,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close location details',
                            onPressed: () => setState(() => selected = null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Text(
                        '${selected!['gouvernorat'] ?? 'Tunisia'} · ${selected!['_kind']} · ${selected!['lat']}, ${selected!['lng']}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(fontSize: 11),
                      ),
                      if (selected!['address']?.toString().isNotEmpty == true)
                        Text(selected!['address'].toString()),
                      if (selected!['opening_hours']?.toString().isNotEmpty ==
                          true)
                        Text('Hours: ${selected!['opening_hours']}'),
                      if (selected!['contact_phone']?.toString().isNotEmpty ==
                          true)
                        Text('Phone: ${selected!['contact_phone']}'),
                      if (selected!['is_location_approximate'] == true ||
                          selected!['description']?.toString().contains(
                                'approximated at the governorate center',
                              ) ==
                              true)
                        const Text(
                          'Approximate governorate location',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.deepOrange,
                          ),
                        ),
                      Wrap(
                        children: [
                          TextButton.icon(
                            onPressed: () => _openDetails(selected!),
                            icon: const Icon(Icons.open_in_new, size: 17),
                            label: const Text('Full details'),
                          ),
                          TextButton.icon(
                            onPressed: () => _openDirections(selected!),
                            icon: const Icon(
                              Icons.directions_outlined,
                              size: 18,
                            ),
                            label: const Text('Directions'),
                          ),
                          if (selected!['contact_phone']
                                  ?.toString()
                                  .isNotEmpty ==
                              true)
                            TextButton.icon(
                              onPressed: () => _callLocation(
                                selected!['contact_phone'].toString(),
                              ),
                              icon: const Icon(Icons.call_outlined, size: 18),
                              label: const Text('Call'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 5),
            child: Row(
              children: [
                Text(
                  '${items.length} mapped ${items.length == 1 ? 'location' : 'locations'}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                const Icon(Icons.circle, size: 8, color: Color(0xff27815a)),
                const SizedBox(width: 5),
                Text(
                  'Live directory',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No locations match these filters.'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final e = items[i];
                      final buyer = e['_kind'] == 'Recovery partner';
                      final collection = e['_kind'].toString().startsWith(
                        'Collection point',
                      );
                      final active = selected?['id'] == e['id'];
                      return Card(
                        color: active
                            ? Theme.of(context).colorScheme.primaryContainer
                                  .withValues(alpha: .35)
                            : null,
                        child: ListTile(
                          onTap: () => _openDetails(e),
                          leading: CircleAvatar(
                            backgroundColor: collection
                                ? const Color(0xffe8e4fa)
                                : buyer
                                ? const Color(0xfffff0dc)
                                : const Color(0xffe0efe5),
                            child: Icon(
                              collection
                                  ? Icons.place_outlined
                                  : buyer
                                  ? Icons.recycling
                                  : Icons.factory_outlined,
                              color: collection
                                  ? const Color(0xff6956a5)
                                  : buyer
                                  ? const Color(0xffb77938)
                                  : const Color(0xff236749),
                            ),
                          ),
                          title: Text(
                            e['name']?.toString() ?? 'Organization',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${e['gouvernorat'] ?? 'Tunisia'} · ${e['_kind']}\n${((e['available_waste_types'] ?? e['accepts_waste_types'] ?? const []) as List).map(materialLabel).join(' · ')}',
                            maxLines: 2,
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );
}

class CollectionPointsView extends StatefulWidget {
  const CollectionPointsView({
    required this.api,
    required this.user,
    this.onChanged,
    super.key,
  });
  final ApiClient api;
  final Map<String, dynamic> user;
  final VoidCallback? onChanged;

  @override
  State<CollectionPointsView> createState() => _CollectionPointsViewState();
}

class _CollectionPointsViewState extends State<CollectionPointsView> {
  late Future<List<dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = widget.api.myCollectionPoints();
  }

  Future<void> _reload() async {
    final request = widget.api.myCollectionPoints();
    setState(() {
      future = request;
    });
    await request;
  }

  Future<void> _openForm([Map<String, dynamic>? point]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .92,
        child: CollectionPointForm(
          api: widget.api,
          user: widget.user,
          existing: point,
        ),
      ),
    );
    if (saved != true || !mounted) return;
    await _reload();
    widget.onChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.clac(
            point == null
                ? 'Collection point submitted for verification.'
                : 'Collection point updated and sent for review.',
          ),
        ),
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> point) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.clac('Delete collection point?')),
        content: Text(
          dialogContext.clac(
            'This removes the point from the network. This cannot be undone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.clac('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.clac('Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.api.deleteCollectionPoint(point['id'].toString());
      await _reload();
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.clac('Collection point deleted.'))),
        );
      }
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(exception.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    }
  }

  String _typeLabel(BuildContext context, dynamic value) => switch (value) {
    'pickup_site' => context.clac('Pickup site'),
    'recycling_center' => context.clac('Recycling center'),
    _ => context.clac('Drop-off point'),
  };

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.clac('Collection points'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: Text(context.clac('Add point')),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              context.clac(
                'Add drop-off or pickup points anywhere in Tunisia. New and edited points are reviewed before they appear publicly.',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
      Expanded(
        child: FutureBuilder<List<dynamic>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ErrorState(
                message: snapshot.error.toString(),
                onRetry: _reload,
              );
            }
            if (!snapshot.hasData) {
              return const SkeletonList(count: 4, itemHeight: 120);
            }
            final points = snapshot.data!;
            if (points.isEmpty) {
              return EmptyStateMobile(
                title: context.clac('No collection points yet'),
                body: context.clac(
                  'Add your first drop-off or pickup point. It stays private until an admin verifies it.',
                ),
                action: FilledButton.icon(
                  onPressed: () => _openForm(),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: Text(context.clac('Add point')),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                itemCount: points.length,
                itemBuilder: (context, index) {
                  final point = Map<String, dynamic>.from(points[index] as Map);
                  final verified = point['is_verified'] == true;
                  final active = point['is_active'] != false;
                  final status = !active
                      ? context.clac('Rejected')
                      : verified
                      ? context.clac('Verified')
                      : context.clac('Pending');
                  final materialsText =
                      (point['accepts_waste_types'] as List? ?? const [])
                          .map(materialLabel)
                          .join(' · ');
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                backgroundColor: Color(0xffe8e4fa),
                                child: Icon(
                                  Icons.add_location_alt_outlined,
                                  color: Color(0xff6956a5),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      point['name']?.toString() ??
                                          'Collection point',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '${point['gouvernorat'] ?? ''} · ${_typeLabel(context, point['point_type'])}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              StatusPill(status),
                            ],
                          ),
                          if ((point['address'] ?? '').toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 54),
                              child: Text(
                                point['address'].toString(),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          if (materialsText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 54),
                              child: Text(
                                materialsText,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          if ((point['contact_phone'] ?? '')
                                  .toString()
                                  .isNotEmpty ||
                              (point['opening_hours'] ?? '')
                                  .toString()
                                  .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 54),
                              child: Text(
                                [
                                  if ((point['contact_phone'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    point['contact_phone'].toString(),
                                  if ((point['opening_hours'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    point['opening_hours'].toString(),
                                ].join(' · '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          if (!active)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 54),
                              child: Text(
                                (point['review_note'] ?? '')
                                        .toString()
                                        .trim()
                                        .isNotEmpty
                                    ? (point['review_note']).toString()
                                    : context.clac(
                                        'Edit this point to submit it again for review.',
                                      ),
                                style: const TextStyle(
                                  color: Color(0xffa15b4f),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => CollectionPointDetailScreen(
                                      item: point,
                                      onEdit: () {
                                        Navigator.pop(context);
                                        _openForm(point);
                                      },
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.open_in_new, size: 17),
                                label: const Text('Details'),
                              ),
                              TextButton.icon(
                                onPressed: () => _openForm(point),
                                icon: const Icon(Icons.edit_outlined, size: 17),
                                label: Text(context.clac('Edit')),
                              ),
                              TextButton.icon(
                                onPressed: () => _delete(point),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 17,
                                ),
                                label: Text(context.clac('Delete')),
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
      ),
    ],
  );
}

class CollectionPointForm extends StatefulWidget {
  const CollectionPointForm({
    required this.api,
    required this.user,
    this.existing,
    super.key,
  });
  final ApiClient api;
  final Map<String, dynamic> user;
  final Map<String, dynamic>? existing;

  @override
  State<CollectionPointForm> createState() => _CollectionPointFormState();
}

class _CollectionPointFormState extends State<CollectionPointForm> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final address = TextEditingController();
  final description = TextEditingController();
  final phone = TextEditingController();
  final hours = TextEditingController();
  final lat = TextEditingController();
  final lng = TextEditingController();
  final selectedMaterials = <String>{};
  late String region;
  String pointType = 'drop_off';
  String? error;
  bool saving = false;
  int step = 0;
  bool coordinatesEdited = false;
  Map<String, dynamic>? get existing => widget.existing;
  bool get isEditing => existing != null;
  String get draftKey =>
      'clac_point_draft_${widget.user['id'] ?? widget.user['email'] ?? 'member'}';

  @override
  void initState() {
    super.initState();
    final point = widget.existing;
    if (point == null) {
      region = _defaultRegion();
      final coords = regionCoordinates[region]!;
      lat.text = coords.$1.toString();
      lng.text = coords.$2.toString();
      _restoreDraft();
      return;
    }
    region = _validRegion(point['gouvernorat']) ?? _defaultRegion();
    pointType = point['point_type']?.toString() ?? 'drop_off';
    if (!const {
      'drop_off',
      'pickup_site',
      'recycling_center',
    }.contains(pointType)) {
      pointType = 'drop_off';
    }
    name.text = point['name']?.toString() ?? '';
    address.text = point['address']?.toString() ?? '';
    description.text = point['description']?.toString() ?? '';
    phone.text = point['contact_phone']?.toString() ?? '';
    hours.text = point['opening_hours']?.toString() ?? '';
    selectedMaterials.addAll(
      (point['accepts_waste_types'] as List? ?? const []).map(
        (item) => item.toString(),
      ),
    );
    final coords = regionCoordinates[region]!;
    lat.text = point['lat']?.toString() ?? coords.$1.toString();
    lng.text = point['lng']?.toString() ?? coords.$2.toString();
    // Keep the stored exact pin when the governorate changes.
    coordinatesEdited = true;
  }

  String? _validRegion(dynamic value) {
    final name = value?.toString();
    return name != null && regionCoordinates.containsKey(name) ? name : null;
  }

  String _defaultRegion() =>
      _validRegion(widget.user['gouvernorat']) ?? 'Tunis';

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    name.text = prefs.getString('${draftKey}_name') ?? '';
    address.text = prefs.getString('${draftKey}_address') ?? '';
    description.text = prefs.getString('${draftKey}_description') ?? '';
    phone.text = prefs.getString('${draftKey}_phone') ?? '';
    hours.text = prefs.getString('${draftKey}_hours') ?? '';
    final savedRegion = prefs.getString('${draftKey}_region');
    if (savedRegion != null && regionCoordinates.containsKey(savedRegion)) {
      region = savedRegion;
    }
    final savedType = prefs.getString('${draftKey}_type');
    if (savedType != null &&
        const {
          'drop_off',
          'pickup_site',
          'recycling_center',
        }.contains(savedType)) {
      pointType = savedType;
    }
    lat.text = prefs.getString('${draftKey}_lat') ?? lat.text;
    lng.text = prefs.getString('${draftKey}_lng') ?? lng.text;
    selectedMaterials.addAll(
      prefs.getStringList('${draftKey}_materials') ?? const [],
    );
    coordinatesEdited = prefs.getBool('${draftKey}_exact') ?? false;
    setState(() {});
  }

  Future<void> _saveDraft({bool showMessage = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${draftKey}_name', name.text.trim());
    await prefs.setString('${draftKey}_address', address.text.trim());
    await prefs.setString('${draftKey}_description', description.text.trim());
    await prefs.setString('${draftKey}_phone', phone.text.trim());
    await prefs.setString('${draftKey}_hours', hours.text.trim());
    await prefs.setString('${draftKey}_region', region);
    await prefs.setString('${draftKey}_type', pointType);
    await prefs.setString('${draftKey}_lat', lat.text.trim());
    await prefs.setString('${draftKey}_lng', lng.text.trim());
    await prefs.setStringList(
      '${draftKey}_materials',
      selectedMaterials.toList(),
    );
    await prefs.setBool('${draftKey}_exact', coordinatesEdited);
    if (showMessage && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.clac('Collection point draft saved on this device.'),
          ),
        ),
      );
    }
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    for (final suffix in [
      'name',
      'address',
      'description',
      'phone',
      'hours',
      'region',
      'type',
      'lat',
      'lng',
      'materials',
      'exact',
    ]) {
      await prefs.remove('${draftKey}_$suffix');
    }
  }

  @override
  void dispose() {
    name.dispose();
    address.dispose();
    description.dispose();
    phone.dispose();
    hours.dispose();
    lat.dispose();
    lng.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (name.text.trim().isEmpty) {
      setState(() {
        step = 0;
        error = context.clac('Enter a name');
      });
      return;
    }
    if (selectedMaterials.isEmpty) {
      setState(() {
        step = 1;
        error = context.clac('Choose at least one accepted material.');
      });
      return;
    }
    if (!formKey.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final payload = <String, dynamic>{
        'name': name.text.trim(),
        'point_type': pointType,
        'address': address.text.trim(),
        'gouvernorat': region,
        'lat': double.parse(lat.text),
        'lng': double.parse(lng.text),
        'accepts_waste_types': selectedMaterials.toList(),
        'description': description.text.trim(),
        'contact_phone': phone.text.trim(),
        'opening_hours': hours.text.trim(),
      };
      if (isEditing) {
        await widget.api.updateCollectionPoint(
          existing!['id'].toString(),
          payload,
        );
      } else {
        await widget.api.createCollectionPoint(payload);
        await _clearDraft();
      }
      if (mounted) {
        await showClacSuccessSheet(
          context,
          title: isEditing ? 'Changes sent for review' : 'Point submitted',
          body: isEditing
              ? 'Your updated point is back in the admin review queue.'
              : 'An administrator will review the point before it appears on the public map.',
          actionLabel: 'Back to my points',
        );
        if (mounted) Navigator.pop(context, true);
      }
    } catch (exception) {
      if (!isEditing) await _saveDraft(showMessage: false);
      if (mounted) {
        setState(
          () => error = exception.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _pickOnMap() async {
    final point = await showDialog<(double, double)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.clac('Tap the exact site location')),
        content: SizedBox(
          width: 620,
          height: 440,
          child: _TunisiaMap(
            items: const [],
            selected: null,
            onSelect: (_) {},
            onMapTap: (latValue, lngValue) =>
                Navigator.pop(dialogContext, (latValue, lngValue)),
          ),
        ),
      ),
    );
    if (point == null || !mounted) return;
    setState(() {
      lat.text = point.$1.toStringAsFixed(6);
      lng.text = point.$2.toStringAsFixed(6);
      coordinatesEdited = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;
    const stepTitles = ['Basics', 'Details', 'Location'];
    return Padding(
      padding: EdgeInsets.only(bottom: insets),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.clac(
                          isEditing
                              ? 'Edit collection point'
                              : 'Add a collection point',
                        ),
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Step ${step + 1} of 3 · ${stepTitles[step]}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.clac('Cancel'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Row(
              children: List.generate(3, (index) {
                final active = step >= index;
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: index == 2 ? 0 : 5),
                    decoration: BoxDecoration(
                      color: active
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Form(
              key: formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                children: [
                  if (error != null) ...[
                    ErrorBanner(error!),
                    const SizedBox(height: 10),
                  ],
                  if (step == 0) ...[
                    const InfoBanner(
                      title: 'New points start private',
                      body:
                          'An administrator reviews every new or edited point before it appears publicly on the network map.',
                      tone: BannerTone.info,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: name,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: context.clac('Point name'),
                        hintText: 'e.g. GreenMinds Sousse drop-off',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? context.clac('Enter a name')
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: pointType,
                      decoration: InputDecoration(
                        labelText: context.clac('Point type'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'drop_off',
                          child: Text(context.clac('Drop-off point')),
                        ),
                        DropdownMenuItem(
                          value: 'pickup_site',
                          child: Text(context.clac('Pickup site')),
                        ),
                        DropdownMenuItem(
                          value: 'recycling_center',
                          child: Text(context.clac('Recycling center')),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => pointType = v ?? 'drop_off'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: address,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: context.clac('Address or landmark'),
                        hintText:
                            'Street, industrial zone, or nearest landmark',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: description,
                      minLines: 3,
                      maxLines: 5,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        labelText: context.clac('Description (optional)'),
                        hintText:
                            'What can people drop off here? Any access notes?',
                      ),
                    ),
                  ],
                  if (step == 1) ...[
                    const InfoBanner(
                      title: 'Help people use this point',
                      body:
                          'Add a phone number, opening hours and the materials you accept. These details appear on the public point page.',
                      tone: BannerTone.success,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.call_outlined, size: 19),
                        labelText: context.clac(
                          'Point contact phone (optional)',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: hours,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.schedule_outlined,
                          size: 19,
                        ),
                        labelText: context.clac('Opening hours (optional)'),
                        hintText: 'Mon–Sat, 8:00–17:00',
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.clac('Materials accepted'),
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                        Text(
                          '${selectedMaterials.length} selected',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: materials.entries
                          .map(
                            (entry) => FilterChip(
                              label: Text(entry.value),
                              selected: selectedMaterials.contains(entry.key),
                              onSelected: (on) => setState(
                                () => on
                                    ? selectedMaterials.add(entry.key)
                                    : selectedMaterials.remove(entry.key),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    if (selectedMaterials.isEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Choose at least one material before continuing.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                  if (step == 2) ...[
                    const InfoBanner(
                      title: 'Pin the exact site',
                      body:
                          'The governorate center is only a starting point. Use the map or coordinates to place the pin on the real entrance.',
                      tone: BannerTone.warning,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey(region),
                      initialValue: region,
                      decoration: InputDecoration(
                        labelText: context.clac('Governorate'),
                      ),
                      items: governorates
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          region = v;
                          if (!coordinatesEdited) {
                            final coords = regionCoordinates[v]!;
                            lat.text = coords.$1.toString();
                            lng.text = coords.$2.toString();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: lat,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: InputDecoration(
                              labelText: context.clac('Latitude'),
                            ),
                            validator: _validateLatitude,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: lng,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            decoration: InputDecoration(
                              labelText: context.clac('Longitude'),
                            ),
                            validator: _validateLongitude,
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _pickOnMap,
                        icon: const Icon(Icons.pin_drop_outlined, size: 19),
                        label: Text(context.clac('Select on map')),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClacCard(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: theme.brightness == Brightness.dark ? .25 : .5,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Eyebrow('REVIEW BEFORE SUBMITTING'),
                          const SizedBox(height: 9),
                          Text(
                            name.text.trim().isEmpty
                                ? 'Untitled collection point'
                                : name.text.trim(),
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$region · ${_pointTypeLabel(pointType)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: .82,
                              ),
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            '${selectedMaterials.length} material${selectedMaterials.length == 1 ? '' : 's'} · ${coordinatesEdited ? 'Exact pin' : 'Approximate pin'}${isEditing ? ' · Editing sends this point back to review' : ''}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: .82,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isEditing) ...[
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: _saveDraft,
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: Text(context.clac('Save draft on this device')),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (step > 0) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _previousStep,
                        icon: const Icon(Icons.arrow_back, size: 17),
                        label: Text(context.clac('Back')),
                      ),
                    ),
                    const SizedBox(width: 9),
                  ],
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: saving ? null : _nextStep,
                      icon: saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              step == 2
                                  ? Icons.send_outlined
                                  : Icons.arrow_forward,
                              size: 18,
                            ),
                      label: Text(
                        context.clac(
                          saving
                              ? (isEditing ? 'Saving…' : 'Submitting…')
                              : step == 2
                              ? (isEditing
                                    ? 'Save changes'
                                    : 'Submit for verification')
                              : 'Continue',
                        ),
                      ),
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

  String _pointTypeLabel(String value) => switch (value) {
    'pickup_site' => context.clac('Pickup site'),
    'recycling_center' => context.clac('Recycling center'),
    _ => context.clac('Drop-off point'),
  };

  void _previousStep() {
    if (step == 0) return;
    setState(() {
      step -= 1;
      error = null;
    });
  }

  Future<void> _nextStep() async {
    if (step == 0) {
      setState(() => error = null);
      if (!formKey.currentState!.validate()) return;
      setState(() => step = 1);
      return;
    }
    if (step == 1) {
      if (selectedMaterials.isEmpty) {
        setState(
          () => error = context.clac('Choose at least one accepted material.'),
        );
        return;
      }
      setState(() {
        error = null;
        step = 2;
      });
      return;
    }
    await submit();
  }

  String? _validateLatitude(String? value) {
    final n = double.tryParse(value ?? '');
    if (n == null) return context.clac('Enter a valid number');
    if (n < 30 || n > 38.5) {
      return context.clac('Latitude must be inside Tunisia.');
    }
    return null;
  }

  String? _validateLongitude(String? value) {
    final n = double.tryParse(value ?? '');
    if (n == null) return context.clac('Enter a valid number');
    if (n < 7 || n > 12.5) {
      return context.clac('Longitude must be inside Tunisia.');
    }
    return null;
  }
}

class _TunisiaMap extends StatefulWidget {
  const _TunisiaMap({
    required this.items,
    required this.selected,
    required this.onSelect,
    this.onMapTap,
    this.onBoundsChanged,
  });
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? selected;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final void Function(double latitude, double longitude)? onMapTap;
  final ValueChanged<String>? onBoundsChanged;
  @override
  State<_TunisiaMap> createState() => _TunisiaMapState();
}

class _TunisiaMapState extends State<_TunisiaMap> {
  static const int zoom = 7;
  static const int firstX = 65;
  static const int firstY = 48;
  static const double tileSize = 128;
  static const double sceneWidth = tileSize * 5;
  static const double sceneHeight = tileSize * 6;
  final TransformationController transform = TransformationController();
  bool centered = false;
  Size? viewportSize;
  final Map<int, Offset> _pointerStarts = {};

  void _handleMapTap(Offset viewportPoint) {
    final callback = widget.onMapTap;
    if (callback == null) return;
    final scene = transform.toScene(viewportPoint);
    final worldSize = (1 << zoom) * tileSize;
    final worldX = firstX * tileSize + scene.dx;
    final worldY = firstY * tileSize + scene.dy;
    final longitude = worldX / worldSize * 360 - 180;
    final normalizedY = 1 - 2 * worldY / worldSize;
    final mercator = math.pi * normalizedY;
    final sinhMercator = (math.exp(mercator) - math.exp(-mercator)) / 2;
    final latitude = math.atan(sinhMercator) * 180 / math.pi;
    if (latitude >= 30 &&
        latitude <= 38.5 &&
        longitude >= 7 &&
        longitude <= 12.5) {
      callback(latitude, longitude);
    }
  }

  void _reportBounds(double width, double height) {
    final callback = widget.onBoundsChanged;
    if (callback == null || width <= 0 || height <= 0) return;
    final topLeft = transform.toScene(Offset.zero);
    final bottomRight = transform.toScene(Offset(width, height));
    final worldSize = (1 << zoom) * tileSize;
    final west = ((firstX * tileSize + topLeft.dx) / worldSize * 360 - 180)
        .clamp(7.0, 12.5);
    final east = ((firstX * tileSize + bottomRight.dx) / worldSize * 360 - 180)
        .clamp(7.0, 12.5);
    double latitude(double sceneY) {
      final worldY = firstY * tileSize + sceneY;
      final mercator = math.pi * (1 - 2 * worldY / worldSize);
      final sinhMercator = (math.exp(mercator) - math.exp(-mercator)) / 2;
      return (math.atan(sinhMercator) * 180 / math.pi)
          .clamp(30.0, 38.5)
          .toDouble();
    }

    final north = latitude(topLeft.dy);
    final south = latitude(bottomRight.dy);
    if (west >= east || south >= north) return;
    callback(
      '${west.toStringAsFixed(4)},${south.toStringAsFixed(4)},${east.toStringAsFixed(4)},${north.toStringAsFixed(4)}',
    );
  }

  @override
  void didUpdateWidget(covariant _TunisiaMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected?['id'] != widget.selected?['id'] &&
        widget.selected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final size = viewportSize;
        final lat = double.tryParse(widget.selected!['lat'].toString());
        final lng = double.tryParse(widget.selected!['lng'].toString());
        if (!mounted || size == null || lat == null || lng == null) return;
        final scale = transform.value
            .getMaxScaleOnAxis()
            .clamp(1.65, 5.0)
            .toDouble();
        final x = _worldX(lng) - firstX * tileSize;
        final y = _worldY(lat) - firstY * tileSize;
        transform.value = Matrix4.translationValues(
          size.width / 2 - x * scale,
          size.height / 2 - y * scale,
          0,
        )..scaleByDouble(scale, scale, scale, 1);
        _reportBounds(size.width, size.height);
        setState(() {});
      });
    }
  }

  void _zoom(double factor) {
    final size = viewportSize;
    if (size == null) return;
    final matrix = transform.value;
    final current = matrix.getMaxScaleOnAxis();
    final next = (current * factor).clamp(.7, 5.0).toDouble();
    final ratio = next / current;
    final tx = matrix.entry(0, 3);
    final ty = matrix.entry(1, 3);
    transform.value = Matrix4.translationValues(
      size.width / 2 - (size.width / 2 - tx) * ratio,
      size.height / 2 - (size.height / 2 - ty) * ratio,
      0,
    )..scaleByDouble(next, next, next, 1);
    setState(() {});
    _reportBounds(size.width, size.height);
  }

  void _zoomToPoint(double x, double y) {
    final size = viewportSize;
    if (size == null) return;
    final next = (transform.value.getMaxScaleOnAxis() * 1.7)
        .clamp(1.2, 5.0)
        .toDouble();
    transform.value = Matrix4.translationValues(
      size.width / 2 - x * next,
      size.height / 2 - y * next,
      0,
    )..scaleByDouble(next, next, next, 1.0);
    setState(() {});
    _reportBounds(size.width, size.height);
  }

  @override
  void dispose() {
    transform.dispose();
    super.dispose();
  }

  double _worldX(double longitude) =>
      (longitude + 180) / 360 * (1 << zoom) * tileSize;

  double _worldY(double latitude) {
    final lat = latitude.clamp(-85.05, 85.05) * math.pi / 180;
    return (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) /
        2 *
        (1 << zoom) *
        tileSize;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      viewportSize = Size(box.maxWidth, box.maxHeight);
      if (!centered && box.maxWidth > 0 && box.maxHeight > 0) {
        centered = true;
        final centerX = _worldX(9.55) - firstX * tileSize;
        final centerY = _worldY(34.1) - firstY * tileSize;
        const initialScale = 1.65;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            transform.value = Matrix4.translationValues(
              box.maxWidth / 2 - centerX * initialScale,
              box.maxHeight / 2 - centerY * initialScale,
              0,
            )..scaleByDouble(initialScale, initialScale, initialScale, 1);
            setState(() {});
            _reportBounds(box.maxWidth, box.maxHeight);
          }
        });
      }
      final matrix = transform.value;
      final scale = matrix.getMaxScaleOnAxis().clamp(.7, 5.0);
      final tx = matrix.entry(0, 3);
      final ty = matrix.entry(1, 3);
      final firstVisibleCol = ((-tx / scale) / tileSize).floor() - 1;
      final lastVisibleCol =
          ((box.maxWidth - tx) / scale / tileSize).ceil() + 1;
      final firstVisibleRow = ((-ty / scale) / tileSize).floor() - 1;
      final lastVisibleRow =
          ((box.maxHeight - ty) / scale / tileSize).ceil() + 1;
      final markerPositions = <ProjectedMapMarker>[];
      final clusterSize = 44 / scale;
      for (final item in widget.items) {
        final lat = double.tryParse(item['lat'].toString());
        final lng = double.tryParse(item['lng'].toString());
        if (lat == null || lng == null) continue;
        final x = _worldX(lng) - firstX * tileSize;
        final y = _worldY(lat) - firstY * tileSize;
        if (x < 0 || x > sceneWidth || y < 0 || y > sceneHeight) continue;
        markerPositions.add(ProjectedMapMarker(item: item, x: x, y: y));
      }
      final markerGroups = clusterMapMarkers(
        markerPositions,
        cellSize: clusterSize,
      );
      return Stack(
        children: [
          if (!mapTileProviderConfigured)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  color: const Color(0xeeffffff),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: const Text(
                    'Configure MAP_TILE_API_KEY for the selected provider.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xff6b5942),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: ClipRect(
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: widget.onMapTap == null
                    ? null
                    : (event) =>
                          _pointerStarts[event.pointer] = event.localPosition,
                onPointerUp: widget.onMapTap == null
                    ? null
                    : (event) {
                        final start = _pointerStarts.remove(event.pointer);
                        if (start != null &&
                            (event.localPosition - start).distance < 12) {
                          _handleMapTap(event.localPosition);
                        }
                      },
                onPointerCancel: (event) =>
                    _pointerStarts.remove(event.pointer),
                child: InteractiveViewer(
                  transformationController: transform,
                  minScale: .7,
                  maxScale: 5,
                  boundaryMargin: const EdgeInsets.all(300),
                  constrained: false,
                  panEnabled: true,
                  scaleEnabled: true,
                  onInteractionUpdate: (_) {
                    setState(() {});
                    _reportBounds(box.maxWidth, box.maxHeight);
                  },
                  child: SizedBox(
                    width: sceneWidth,
                    height: sceneHeight,
                    child: Stack(
                      children: [
                        for (var row = 0; row < 6; row++)
                          for (var col = 0; col < 5; col++)
                            if (col >= firstVisibleCol &&
                                col <= lastVisibleCol &&
                                row >= firstVisibleRow &&
                                row <= lastVisibleRow)
                              Positioned(
                                left: col * tileSize,
                                top: row * tileSize,
                                width: tileSize,
                                height: tileSize,
                                child: OsmTile(
                                  key: ValueKey(
                                    '$zoom/${firstX + col}/${firstY + row}',
                                  ),
                                  zoom: zoom,
                                  x: firstX + col,
                                  y: firstY + row,
                                ),
                              ),
                        for (final group in markerGroups)
                          Builder(
                            builder: (context) {
                              final x =
                                  group
                                      .map((marker) => marker.x)
                                      .reduce((a, b) => a + b) /
                                  group.length;
                              final y =
                                  group
                                      .map((marker) => marker.y)
                                      .reduce((a, b) => a + b) /
                                  group.length;
                              if (group.length > 1) {
                                return Positioned(
                                  left: x - 19,
                                  top: y - 19,
                                  child: GestureDetector(
                                    onTap: () => _zoomToPoint(x, y),
                                    child: Container(
                                      width: 38,
                                      height: 38,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xff183f33),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2.5,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black38,
                                            blurRadius: 5,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '${group.length}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }
                              final item = group.single.item;
                              final isBuyer =
                                  item['_kind'] == 'Recovery partner';
                              final isCollectionPoint = item['_kind']
                                  .toString()
                                  .startsWith('Collection point');
                              final active =
                                  widget.selected?['id'] == item['id'];
                              return Positioned(
                                left: x - (active ? 17 : 14),
                                top: y - (active ? 17 : 14),
                                child: GestureDetector(
                                  onTap: () => widget.onSelect(item),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: active ? 34 : 28,
                                    height: active ? 34 : 28,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? const Color(0xff183f33)
                                          : (isCollectionPoint
                                                ? const Color(0xff6956a5)
                                                : isBuyer
                                                ? const Color(0xffd08a42)
                                                : const Color(0xff27815a)),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2.5,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black38,
                                          blurRadius: 5,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      isCollectionPoint
                                          ? Icons.place_outlined
                                          : isBuyer
                                          ? Icons.recycling
                                          : Icons.arrow_upward,
                                      size: active ? 17 : 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xebffffff),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 5),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.pan_tool_alt_outlined,
                      size: 14,
                      color: Color(0xff205b45),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Drag to move · Pinch to zoom',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff244136),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 9,
            top: 9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xefffffff),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 5),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Zoom in',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _zoom(1.35),
                    icon: const Icon(Icons.add, color: Color(0xff205b45)),
                  ),
                  IconButton(
                    tooltip: 'Zoom out',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _zoom(1 / 1.35),
                    icon: const Icon(Icons.remove, color: Color(0xff205b45)),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 9,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xebffffff),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 9, color: Color(0xff27815a)),
                    SizedBox(width: 4),
                    Text(
                      'Seller',
                      style: TextStyle(fontSize: 9, color: Color(0xff33443a)),
                    ),
                    SizedBox(width: 9),
                    Icon(Icons.circle, size: 9, color: Color(0xffd08a42)),
                    SizedBox(width: 4),
                    Text(
                      'Recovery partner',
                      style: TextStyle(fontSize: 9, color: Color(0xff33443a)),
                    ),
                    SizedBox(width: 9),
                    Icon(Icons.circle, size: 9, color: Color(0xff6956a5)),
                    SizedBox(width: 4),
                    Text(
                      'Collection point',
                      style: TextStyle(fontSize: 9, color: Color(0xff33443a)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            right: 8,
            bottom: 7,
            child: DecoratedBox(
              decoration: BoxDecoration(color: Colors.white70),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                child: Text(
                  mapTileAttribution,
                  style: TextStyle(fontSize: 8, color: Color(0xff53665a)),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
