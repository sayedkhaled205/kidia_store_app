import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/kidia_colors.dart';
import '../features/page_builder/domain/cms_page_layout.dart';
import '../features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import '../features/home/presentation/providers/home_providers.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<_NavigationItem> _items = [
    _NavigationItem(
	  id: 'home',
      label: 'الرئيسية',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavigationItem(
	  id: 'categories',
      label: 'الأقسام',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
    ),
    _NavigationItem(
	  id: 'wishlist',
      label: 'المفضلة',
      icon: Icons.favorite_border_rounded,
      selectedIcon: Icons.favorite_rounded,
    ),
    _NavigationItem(
	  id: 'account',
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
    final List<_FooterPlacement> placements = _footerPlacements(footer);
    final List<String> order = placements.map((placement) => placement.id).toList(growable: false);
    final List<MapEntry<int, _NavigationItem>> visibleItems = order.map((id) {
		final int index = _items.indexWhere((item) => item.id == id);
		return index < 0 ? null : MapEntry<int, _NavigationItem>(index, _items[index]);
	}).whereType<MapEntry<int, _NavigationItem>>().toList(growable: false);
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
      bottomNavigationBar: !footer.enabled || visibleItems.isEmpty || footer.string('style', 'navigation') == 'product_action'
          ? null
          : SafeArea(
        top: false,
		bottom: footer.boolean('safe_area', true),
        child: Padding(
          padding: EdgeInsets.only(top: footer.number('margin_top', 0).clamp(0, 80), bottom: footer.number('margin_bottom', 0).clamp(0, 80)),
          child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
			border: Border(top: BorderSide(color: _cmsColor(footer.string('border_color', '#E2E6E4'), KidiaColors.divider), width: footer.number('border_width', 1))),
			borderRadius: BorderRadius.vertical(top: Radius.circular(footer.number('top_radius', 0))),
			boxShadow: footer.string('shadow', 'subtle') == 'none' ? null : <BoxShadow>[BoxShadow(color: Colors.black.withValues(alpha: footer.string('shadow', 'subtle') == 'strong' ? .18 : .08), blurRadius: footer.string('shadow', 'subtle') == 'strong' ? 16 : 6)],
          ),
          child: Padding(
            key: const Key('cms-bottom-navigation'),
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width * footer.number('side_spacing_percent', 5).clamp(0, 25) / 100,
            ),
            child: SizedBox(
              height: footer.number('height', 72).clamp(48, 100),
              child: Row(
                children: visibleItems.indexed.map((indexed) {
                  final int visibleIndex = indexed.$1;
                  final MapEntry<int, _NavigationItem> entry = indexed.$2;
                  final _NavigationItem item = entry.value;
                  final bool selected = visibleIndex == (selectedIndex < 0 ? 0 : selectedIndex);
                  final Color color = selected ? activeColor : inactiveColor;
				  final _FooterPlacement placement = placements.firstWhere((entry) => entry.id == item.id);
                  return Expanded(
					flex: (placement.width * 100).round().clamp(1, 10000).toInt(),
                    child: InkWell(
                      key: Key('cms-bottom-nav-${item.id}'),
                      onTap: () => _openBranch(ref, entry.key),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          _NavigationIcon(
                            icon: _footerIcon(footer, item, selected),
                            color: color,
                            size: footer.number('icon_size', 24),
                          ),
                          if (footer.boolean('show_labels', true)) ...<Widget>[
                            SizedBox(height: footer.number('icon_label_gap', 3).clamp(0, 12)),
                            Text(
                              footer.string('${item.id}_label', item.label),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: color,
                                fontSize: footer.number('label_size', 11).clamp(8, 20),
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_FooterPlacement> _footerPlacements(CmsPageComponent footer) {
    final Map<String, dynamic> json = footer.json('layout_json');
    final dynamic rawRows = json['rows'];
    if (rawRows is List) {
      final List<_FooterPlacement> result = <_FooterPlacement>[];
      for (final dynamic rawRow in rawRows.take(3)) {
        if (rawRow is! Map || rawRow['columns'] is! List) continue;
        final List<dynamic> columns = rawRow['columns'] as List<dynamic>;
        for (final dynamic rawColumn in columns.take(6)) {
          if (rawColumn is! Map) continue;
          final double width = (rawColumn['width'] as num?)?.toDouble() ?? (100 / columns.length);
          final dynamic rawItems = rawColumn['items'];
          if (rawItems is List) {
            result.addAll(rawItems.map((item) => _FooterPlacement('$item', width)));
          }
        }
      }
      if (result.isNotEmpty) return result;
    }
    final dynamic legacyItems = json['items'];
    final List<String> ids = legacyItems is List ? legacyItems.map((item) => '$item').toList() : _items.map((item) => item.id).toList();
    return ids.map((id) => _FooterPlacement(id, 100 / ids.length)).toList(growable: false);
  }

  IconData _footerIcon(CmsPageComponent footer, _NavigationItem item, bool selected) {
	final String variant = footer.string('${item.id}_icon_variant', '');
	return switch (item.id) {
	  'home' => variant == 'filled' || selected ? Icons.home_rounded : variant == 'rounded' ? Icons.other_houses_outlined : Icons.home_outlined,
	  'categories' => variant == 'list' ? Icons.view_list_outlined : variant == 'category' ? Icons.category_outlined : selected ? Icons.grid_view_rounded : Icons.grid_view_outlined,
	  'wishlist' => variant == 'bookmark' ? (selected ? Icons.bookmark : Icons.bookmark_border) : selected ? Icons.favorite_rounded : Icons.favorite_border_rounded,
	  'account' => variant == 'circle' ? Icons.account_circle_outlined : selected ? Icons.person_rounded : Icons.person_outline_rounded,
	  _ => selected ? item.selectedIcon : item.icon,
	};
  }

  String _pageForPath(String path) {
    if (path == '/home' || path == '/') return 'home';
    if (path == '/categories') return 'category';
    if (path.startsWith('/product/')) return 'product';
    if (path.startsWith('/wishlist')) return 'wishlist';
    if (path.startsWith('/account')) return 'account';
    if (path.startsWith('/categories/') ||
        path.startsWith('/collection/') ||
        path.startsWith('/brand/') ||
        path.startsWith('/products')) {
      return 'catalog';
    }
    return navigationShell.currentIndex == 0
        ? 'home'
        : navigationShell.currentIndex == 1
        ? 'category'
        : navigationShell.currentIndex == 2
        ? 'wishlist'
        : navigationShell.currentIndex == 3
        ? 'account'
        : 'catalog';
  }

  void _openBranch(WidgetRef ref, int index) {
    if (index == 0) {
      ref.invalidate(homeLayoutProvider);
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == 1 || index == navigationShell.currentIndex,
    );
  }
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({required this.icon, required this.color, required this.size});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      color: color,
	  size: size,
    );
  }
}

Color _cmsColor(String value, Color fallback) {
  final String normalized = value.replaceFirst('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized)) return fallback;
  return Color(int.parse('FF$normalized', radix: 16));
}

class _FooterPlacement {
  const _FooterPlacement(this.id, this.width);

  final String id;
  final double width;
}

class _NavigationItem {
  const _NavigationItem({
	required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String id;

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
