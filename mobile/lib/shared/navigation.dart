import 'package:flutter/material.dart';
import 'package:clac_mobile/shared/strings.dart';

class ClacNavItem {
  const ClacNavItem({
    required this.label,
    required this.icon,
    this.pageIndex,
    this.isMore = false,
  });

  final String label;
  final IconData icon;
  final int? pageIndex;
  final bool isMore;
}

/// The five primary destinations for a signed-in role. The final item opens
/// the full navigation drawer instead of switching pages.
List<ClacNavItem> rolePrimaryDestinations(String? role) => [
  const ClacNavItem(
    label: 'Home',
    icon: Icons.space_dashboard_outlined,
    pageIndex: 0,
  ),
  if (role == 'collector')
    const ClacNavItem(
      label: 'Points',
      icon: Icons.add_location_alt_outlined,
      pageIndex: 1,
    )
  else if (role == 'admin')
    const ClacNavItem(
      label: 'Review',
      icon: Icons.fact_check_outlined,
      pageIndex: 11,
    )
  else if (role == 'processor')
    const ClacNavItem(
      label: 'Marketplace',
      icon: Icons.storefront_outlined,
      pageIndex: 1,
    )
  else
    const ClacNavItem(
      label: 'Materials',
      icon: Icons.inventory_2_outlined,
      pageIndex: 1,
    ),
  const ClacNavItem(
    label: 'Requests',
    icon: Icons.receipt_long_outlined,
    pageIndex: 2,
  ),
  if (role == 'admin')
    const ClacNavItem(label: 'Impact', icon: Icons.eco_outlined, pageIndex: 8)
  else if (role == 'processor')
    const ClacNavItem(label: 'Network', icon: Icons.map_outlined, pageIndex: 4)
  else if (role == 'collector')
    const ClacNavItem(label: 'Map', icon: Icons.map_outlined, pageIndex: 4)
  else
    const ClacNavItem(label: 'Impact', icon: Icons.eco_outlined, pageIndex: 8),
  const ClacNavItem(label: 'More', icon: Icons.menu, isMore: true),
];

class ClacBottomNavigation extends StatelessWidget {
  const ClacBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
    this.unreadNotifications = 0,
    this.collectionMode = false,
    this.items,
    this.notificationTab = 3,
    super.key,
  });

  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final int unreadNotifications;
  final bool collectionMode;
  final List<ClacNavItem>? items;
  final int notificationTab;

  static const labels = [
    'Overview',
    'Materials',
    'Requests',
    'Alerts',
    'Map',
    'Profile',
  ];
  static const icons = [
    Icons.space_dashboard_outlined,
    Icons.inventory_2_outlined,
    Icons.receipt_long_outlined,
    Icons.notifications_outlined,
    Icons.map_outlined,
    Icons.person_outline,
  ];

  List<ClacNavItem> get _destinations {
    final custom = items;
    if (custom != null) return custom;
    final tabLabels = List<String>.from(labels);
    final tabIcons = List<IconData>.from(icons);
    if (collectionMode) {
      tabLabels[1] = 'Collection points';
      tabIcons[1] = Icons.add_location_alt_outlined;
    }
    return List.generate(
      tabLabels.length,
      (index) => ClacNavItem(label: tabLabels[index], icon: tabIcons[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final surfaceColor = dark ? const Color(0xFF18231D) : Colors.white;
    final borderColor = dark
        ? const Color(0xFF2C3A31)
        : const Color(0xffe7ede8);
    final activeColor = dark
        ? const Color(0xFF9BDCB4)
        : const Color(0xff236749);
    final inactiveColor = dark
        ? const Color(0xFFAFC2B5)
        : const Color(0xff718076);
    final indicatorColor = dark
        ? const Color(0xFF274334)
        : const Color(0xFFE4F0E7);
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(destinations.length, (tab) {
              final item = destinations[tab];
              final active = selectedIndex == tab;
              final color = active ? activeColor : inactiveColor;
              final showBadge =
                  items == null &&
                  tab == notificationTab &&
                  unreadNotifications > 0;
              final icon = Icon(item.icon, color: color, size: 21);
              return Expanded(
                child: Semantics(
                  selected: active,
                  button: true,
                  label: context.clac(item.label),
                  child: InkWell(
                    onTap: () {
                      if (item.isMore) {
                        onSelected(-1);
                      } else {
                        onSelected(tab);
                      }
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: active ? indicatorColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: showBadge
                              ? Badge(
                                  isLabelVisible: true,
                                  label: Text(
                                    unreadNotifications > 99
                                        ? '99+'
                                        : '$unreadNotifications',
                                  ),
                                  child: icon,
                                )
                              : icon,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.clac(item.label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            color: color,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
