import 'package:flutter/material.dart';

import 'package:clac_mobile/core/api_client.dart';
import 'package:clac_mobile/core/app_theme.dart';
import 'package:clac_mobile/shared/widgets.dart';
import 'package:clac_mobile/features/dashboard/workspace_screens.dart';
import 'package:clac_mobile/features/notifications/notifications_screen.dart';
import 'package:clac_mobile/features/network/processor_screen.dart';
import 'package:clac_mobile/features/profile/profile_screen.dart';
import 'package:clac_mobile/features/dashboard/activity_feed_screen.dart';
import 'package:clac_mobile/features/dashboard/impact_screen.dart';
import 'package:clac_mobile/features/dashboard/leaderboard_screen.dart';
import 'package:clac_mobile/features/profile/settings_screen.dart';
import 'package:clac_mobile/features/network/network_screen.dart';
import 'package:clac_mobile/shared/navigation.dart';
import 'package:clac_mobile/features/admin/admin_review_screen.dart';
import 'package:clac_mobile/shared/strings.dart';

class MobileShell extends StatefulWidget {
  const MobileShell({
    required this.user,
    required this.api,
    required this.onSignOut,
    required this.onLocaleChange,
    required this.onThemeChange,
    super.key,
  });
  final Map<String, dynamic> user;
  final ApiClient api;
  final Future<void> Function() onSignOut;
  final ValueChanged<String> onLocaleChange;
  final ValueChanged<bool> onThemeChange;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  final scaffoldKey = GlobalKey<ScaffoldState>();
  int index = 0;
  int unreadNotifications = 0;
  bool get isAdmin => widget.user['role'] == 'admin';
  bool get isCollector => widget.user['role'] == 'collector';

  String get roleLabel => switch (widget.user['role']) {
    'admin' => 'Network administrator',
    'collector' => 'Collection specialist',
    'processor' => 'Recovery partner',
    _ => 'Material seller',
  };

  List<String> get _baseLabels => [
    'Overview',
    isCollector ? 'Collection points' : 'Materials',
    'Requests',
    'Notifications',
    'Tunisia map',
    'Profile',
    'Recovery partners',
    'Community',
    'Impact',
    'Leaderboard',
    'Settings',
  ];
  List<IconData> get _baseIcons => [
    Icons.space_dashboard_outlined,
    isCollector ? Icons.add_location_alt_outlined : Icons.inventory_2_outlined,
    Icons.receipt_long_outlined,
    Icons.notifications_outlined,
    Icons.map_outlined,
    Icons.person_outline,
    Icons.factory_outlined,
    Icons.dynamic_feed_outlined,
    Icons.eco_outlined,
    Icons.emoji_events_outlined,
    Icons.settings_outlined,
  ];
  List<String> _labels(BuildContext context) =>
      [..._baseLabels, if (isAdmin) 'Admin review'].map(context.clac).toList();
  List<IconData> get _icons => [
    ..._baseIcons,
    if (isAdmin) Icons.fact_check_outlined,
  ];

  List<Widget> get _pages => [
    MobileDashboard(
      user: widget.user,
      api: widget.api,
      onOpenMarketplace: () => setState(() => index = 1),
      onOpenNotifications: () => setState(() => index = 3),
      onOpenNetwork: () => setState(() => index = 4),
      onOpenImpact: () => setState(() => index = 8),
      onOpenProfile: () => setState(() => index = 5),
      onOpenRequests: () => setState(() => index = 2),
      onOpenAdmin: () => setState(() => index = 11),
    ),
    isCollector
        ? CollectionPointsView(api: widget.api, user: widget.user)
        : MarketplaceScreen(user: widget.user, api: widget.api),
    RequestsScreen(user: widget.user, api: widget.api),
    NotificationsScreen(
      user: widget.user,
      api: widget.api,
      onUnreadCountChanged: (count) {
        if (mounted && unreadNotifications != count) {
          setState(() => unreadNotifications = count);
        }
      },
    ),
    NetworkScreen(api: widget.api, user: widget.user),
    ProfileScreen(
      user: widget.user,
      api: widget.api,
      onUpdateUser: (_) => setState(() {}),
    ),
    ProcessorScreen(user: widget.user, api: widget.api),
    ActivityFeedScreen(user: widget.user, api: widget.api),
    ImpactScreen(user: widget.user, api: widget.api),
    LeaderboardScreen(user: widget.user, api: widget.api),
    SettingsScreen(
      user: widget.user,
      api: widget.api,
      onSignOut: widget.onSignOut,
      onThemeToggle: widget.onThemeChange,
      onLocaleChange: widget.onLocaleChange,
    ),
    if (isAdmin) AdminReviewScreen(api: widget.api),
  ];

  List<ClacNavItem> get _primary =>
      rolePrimaryDestinations(widget.user['role']?.toString());

  int? get primarySelectedIndex {
    final position = _primary.indexWhere((item) => item.pageIndex == index);
    return position < 0 ? null : position;
  }

  void selectPage(int page) {
    if (page < 0 || page >= _pages.length) return;
    setState(() => index = page);
  }

  void openMore() {
    scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final pages = _pages;
      final labels = _labels(context);
      if (constraints.maxWidth >= 900) return _desktop(pages, labels);
      return Scaffold(
        key: scaffoldKey,
        appBar: AppBar(
          titleSpacing: 16,
          title: const BrandMark(compact: true),
          actions: [
            IconButton(
              tooltip: context.clac('Notifications'),
              onPressed: () => selectPage(3),
              icon: Badge(
                isLabelVisible: unreadNotifications > 0,
                label: Text(
                  unreadNotifications > 99 ? '99+' : '$unreadNotifications',
                ),
                child: const Icon(Icons.notifications_none_outlined),
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: GestureDetector(
                onTap: openMore,
                child: InitialsAvatar(
                  name: widget.user['name']?.toString() ?? 'CLAC member',
                  size: 32,
                ),
              ),
            ),
          ],
        ),
        drawer: Drawer(
          child: SafeArea(
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 22, 20, 14),
                  child: BrandMark(),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(clacRadius),
                  ),
                  child: Row(
                    children: [
                      InitialsAvatar(
                        name: widget.user['name']?.toString() ?? 'CLAC member',
                        size: 38,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.user['name']?.toString() ?? 'CLAC member',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              roleLabel,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: labels.length,
                    itemBuilder: (context, i) {
                      final selected = index == i;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            _icons[i],
                            size: 20,
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : null,
                          ),
                          title: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                          trailing: i == 3 && unreadNotifications > 0
                              ? Badge(
                                  label: Text(
                                    unreadNotifications > 99
                                        ? '99+'
                                        : '$unreadNotifications',
                                  ),
                                )
                              : null,
                          selected: selected,
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer.withValues(alpha: .55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          onTap: () {
                            selectPage(i);
                            Navigator.pop(context);
                          },
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, size: 20),
                  title: Text(
                    context.clac('Sign out'),
                    style: const TextStyle(fontSize: 13.5),
                  ),
                  onTap: widget.onSignOut,
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: ClacBottomNavigation(
          selectedIndex: primarySelectedIndex,
          unreadNotifications: unreadNotifications,
          items: _primary,
          onSelected: (value) {
            if (value == -1) {
              openMore();
              return;
            }
            final item = _primary[value];
            if (item.isMore || item.pageIndex == null) {
              openMore();
            } else {
              selectPage(item.pageIndex!);
            }
          },
        ),
      );
    },
  );

  Widget _desktop(List<Widget> pages, List<String> labels) => Scaffold(
    body: Row(
      children: [
        Container(
          width: 252,
          color: const Color(0xff123d2c),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
                  child: BrandMark(onDark: true),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    context.clac('CIRCULAR NETWORK'),
                    style: const TextStyle(
                      color: Color(0xffa6c1ae),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: labels.length,
                    itemBuilder: (context, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        dense: true,
                        leading: i == 3 && unreadNotifications > 0
                            ? Badge(
                                label: Text(
                                  unreadNotifications > 99
                                      ? '99+'
                                      : '$unreadNotifications',
                                ),
                                child: Icon(
                                  _icons[i],
                                  size: 20,
                                  color: index == i
                                      ? const Color(0xff123d2c)
                                      : const Color(0xffd3e4d8),
                                ),
                              )
                            : Icon(
                                _icons[i],
                                size: 20,
                                color: index == i
                                    ? const Color(0xff123d2c)
                                    : const Color(0xffd3e4d8),
                              ),
                        title: Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 13.5,
                            color: index == i
                                ? const Color(0xff123d2c)
                                : Colors.white,
                            fontWeight: index == i
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        selected: index == i,
                        selectedTileColor: const Color(0xffdceee1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onTap: () => selectPage(i),
                      ),
                    ),
                  ),
                ),
                const Divider(color: Color(0xff436553)),
                ListTile(
                  leading: InitialsAvatar(
                    name: widget.user['name']?.toString() ?? 'CLAC member',
                    size: 36,
                    color: const Color(0xffdceee1),
                  ),
                  title: Text(
                    widget.user['name']?.toString() ?? 'CLAC member',
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    roleLabel,
                    style: const TextStyle(
                      color: Color(0xffb2c9ba),
                      fontSize: 11.5,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'Sign out',
                    onPressed: widget.onSignOut,
                    icon: const Icon(Icons.logout, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Container(
                height: 68,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      labels[index],
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.public,
                      size: 17,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.clac('Tunisia'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(width: 18),
                    IconButton(
                      tooltip: context.clac('Notifications'),
                      onPressed: () => selectPage(3),
                      icon: Badge(
                        isLabelVisible: unreadNotifications > 0,
                        label: Text(
                          unreadNotifications > 99
                              ? '99+'
                              : '$unreadNotifications',
                        ),
                        child: const Icon(Icons.notifications_none),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(index: index, children: pages),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
