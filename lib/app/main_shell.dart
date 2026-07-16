import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/kidia_colors.dart';
import '../core/theme/kidia_typography.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<_NavigationItem> _items = [
    _NavigationItem(
      label: 'الرئيسية',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavigationItem(
      label: 'الأقسام',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
    ),
    _NavigationItem(
      label: 'المفضلة',
      icon: Icons.favorite_border_rounded,
      selectedIcon: Icons.favorite_rounded,
    ),
    _NavigationItem(
      label: 'حسابي',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: KidiaColors.surface,
            border: Border(top: BorderSide(color: KidiaColors.divider)),
          ),
          child: NavigationBar(
            height: 72,
            elevation: 0,
            backgroundColor: KidiaColors.surface,
            indicatorColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _openBranch,
            destinations: _items.map((item) {
              return NavigationDestination(
                icon: _NavigationIcon(
                  icon: item.icon,
                  showBadge: false,
                ),
                selectedIcon: _NavigationIcon(
                  icon: item.selectedIcon,
                  showBadge: false,
                  selected: true,
                ),
                label: item.label,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _openBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation:
          index == 1 || index == navigationShell.currentIndex,
    );
  }
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({
    required this.icon,
    this.showBadge = false,
    this.selected = false,
    this.badgeCount = 0,
  });

  final IconData icon;
  final bool showBadge;
  final bool selected;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(
      icon,
      color: selected ? KidiaColors.primaryDark : KidiaColors.textSecondary,
    );

    if (!showBadge || badgeCount <= 0) {
      return iconWidget;
    }

    return Badge(
      label: Text(
        badgeCount > 99 ? '99+' : '$badgeCount',
        style: KidiaTypography.labelMedium.copyWith(
          color: Colors.white,
          fontSize: 10,
        ),
      ),
      backgroundColor: KidiaColors.secondary,
      child: iconWidget,
    );
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.showBadge = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool showBadge;
}
