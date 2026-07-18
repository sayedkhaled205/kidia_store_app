import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/kidia_colors.dart';
import '../features/page_builder/domain/cms_page_layout.dart';
import '../features/page_builder/presentation/providers/cms_page_layout_providers.dart';

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
    final String page = _pageForPath(GoRouterState.of(context).uri.path);
    final CmsPageLayout pageLayout =
        ref.watch(cmsPageLayoutProvider(page)).value ??
        CmsPageLayout.fallback(page);
    final CmsPageComponent footer = pageLayout.footer;
    final List<MapEntry<int, _NavigationItem>> visibleItems = _items
        .asMap()
        .entries
        .where((MapEntry<int, _NavigationItem> entry) {
          const List<String> keys = <String>[
            'show_home',
            'show_categories',
            'show_wishlist',
            'show_account',
          ];
          return footer.boolean(keys[entry.key], true);
        })
        .toList(growable: false);
    final int selectedIndex = visibleItems.indexWhere(
      (MapEntry<int, _NavigationItem> entry) =>
          entry.key == navigationShell.currentIndex,
    );
    final Color activeColor = _cmsColor(
      footer.string('active_color', '#1F6F61'),
      KidiaColors.primaryDark,
    );
    final Color inactiveColor = _cmsColor(
      footer.string('inactive_color', '#6B7280'),
      KidiaColors.textSecondary,
    );
    final Color backgroundColor = _cmsColor(
      footer.string('background_color', '#FFFFFF'),
      KidiaColors.surface,
    );
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: !footer.enabled || visibleItems.isEmpty
          ? null
          : SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            border: const Border(top: BorderSide(color: KidiaColors.divider)),
          ),
          child: NavigationBar(
            height: footer.number('height', 72).clamp(48, 100),
            elevation: 0,
            backgroundColor: backgroundColor,
            indicatorColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            labelBehavior: footer.boolean('show_labels', true)
                ? NavigationDestinationLabelBehavior.alwaysShow
                : NavigationDestinationLabelBehavior.alwaysHide,
            selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
            onDestinationSelected: (int index) =>
                _openBranch(visibleItems[index].key),
            destinations: visibleItems.map((entry) {
              final _NavigationItem item = entry.value;
              return NavigationDestination(
                icon: _NavigationIcon(icon: item.icon, color: inactiveColor),
                selectedIcon: _NavigationIcon(
                  icon: item.selectedIcon,
                  color: activeColor,
                ),
                label: item.label,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _pageForPath(String path) {
    if (path.startsWith('/product/')) return 'product';
    if (path.startsWith('/wishlist')) return 'wishlist';
    if (path.startsWith('/account')) return 'account';
    if (path.startsWith('/categories/') ||
        path.startsWith('/collection/') ||
        path.startsWith('/brand/') ||
        path.startsWith('/products')) {
      return 'catalog';
    }
    return navigationShell.currentIndex == 2
        ? 'wishlist'
        : navigationShell.currentIndex == 3
        ? 'account'
        : 'catalog';
  }

  void _openBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == 1 || index == navigationShell.currentIndex,
    );
  }
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      color: color,
    );
  }
}

Color _cmsColor(String value, Color fallback) {
  final String normalized = value.replaceFirst('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized)) return fallback;
  return Color(int.parse('FF$normalized', radix: 16));
}

class _NavigationItem {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
