import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/mobishop_colors.dart';
import '../core/config/app_config.dart';
import '../core/analytics/mobile_analytics.dart';
import '../features/page_builder/domain/cms_page_layout.dart';
import '../features/page_builder/domain/cms_footer_label.dart';
import '../features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import '../features/home/presentation/providers/home_providers.dart';
import '../features/catalog/presentation/providers/catalog_category_providers.dart';

class MainShell extends ConsumerStatefulWidget {
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
    _NavigationItem(
      id: 'search',
      label: 'البحث',
      icon: Icons.search_rounded,
      selectedIcon: Icons.search_rounded,
    ),
    _NavigationItem(
      id: 'cart',
      label: 'السلة',
      icon: Icons.shopping_bag_outlined,
      selectedIcon: Icons.shopping_bag,
    ),
    _NavigationItem(
      id: 'orders',
      label: 'الطلبات',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
  ];

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  bool _footerHidden = false;
  static const List<_NavigationItem> _items = MainShell._items;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(mobileAnalyticsProvider).trackInBackground('app_open');
    // Layout providers own completion-based 15-second polling. A second shell
    // timer would invalidate slow initial reads before the page can open.
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!AppConfig.isCmsPreview && state == AppLifecycleState.resumed) {
      ref.read(mobileAnalyticsProvider).trackInBackground('app_resume');
      _refreshRemoteSettings();
    }
  }

  void _refreshRemoteSettings() {
    if (!mounted) return;
    ref.invalidate(homeLayoutProvider);
    ref.invalidate(cmsPageLayoutProvider);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String page = _pageForPath(GoRouterState.of(context).uri.path);
    final AsyncValue<CmsPageLayout> pageLayoutState = ref.watch(
      cmsPageLayoutProvider(page),
    );
    final bool waitingForLayout =
        pageLayoutState.value == null && !pageLayoutState.hasError;
    final CmsPageLayout pageLayout =
        pageLayoutState.value ?? CmsPageLayout.fallback(page);
    final Map<String, bool> pageAvailability = <String, bool>{
      'home': ref.watch(cmsPageLayoutProvider('home')).value?.enabled ?? true,
      'categories':
          ref.watch(cmsPageLayoutProvider('category')).value?.enabled ?? true,
      'wishlist':
          ref.watch(cmsPageLayoutProvider('wishlist')).value?.enabled ?? true,
      'account':
          ref.watch(cmsPageLayoutProvider('account')).value?.enabled ?? true,
    };
    final CmsPageComponent footer = pageLayout.footer;
    final double footerIconSize = footer
        .number('icon_size', 24)
        .clamp(14, 40)
        .toDouble();
    final double footerIconBoxSize = (footerIconSize + 8)
        .clamp(32, 48)
        .toDouble();
    final double footerLabelSize = footer
        .number('label_size', 11)
        .clamp(8, 20)
        .toDouble();
    final String? footerFontFamily = switch (pageLayout.string(
      'font_family',
      'system',
    )) {
      'poppins' => 'Poppins',
      'roboto' => 'Roboto',
      'noto_sans_arabic' => 'Noto Sans Arabic',
      'serif' => 'serif',
      'monospace' => 'monospace',
      _ => null,
    };
    var placements = _footerPlacements(footer);
    // A product action layout can remain saved when selecting navigation.
    // Render navigation defaults without rewriting its saved purchase layout.
    final footerJson = footer.json('layout_json');
    final configuredIds = <String>[];
    if (footerJson['items'] is List) configuredIds.addAll((footerJson['items'] as List).map((id) => '$id'));
    if (footerJson['rows'] is List) {
      for (final row in footerJson['rows'] as List) {
        if (row is! Map || row['columns'] is! List) continue;
        for (final column in row['columns'] as List) {
          if (column is Map && column['items'] is List) configuredIds.addAll((column['items'] as List).map((id) => '$id'));
        }
      }
    }
    if (page == 'product' && footer.string('style','product_action') != 'product_action' &&
        placements.every((p) => p.id.isEmpty) &&
        configuredIds.any((id) => ['share','like','add_to_cart'].contains(id))) {
      placements = _items.take(4).map((item) => _FooterPlacement(item.id,25,0)).toList();
    }
    final List<String> order = placements
        .map((placement) => placement.id)
        .toList(growable: false);
    final List<MapEntry<int, _NavigationItem>> visibleItems = order
        .where((String id) => pageAvailability[id] ?? true)
        .map((id) {
          final int index = _items.indexWhere((item) => item.id == id);
          return index < 0
              ? null
              : MapEntry<int, _NavigationItem>(index, _items[index]);
        })
        .whereType<MapEntry<int, _NavigationItem>>()
        .toList(growable: false);
    final rowCount = placements.map((p) => p.row).toSet().length;
    final minimumRowHeight =
        footerIconBoxSize +
        (footer.boolean('show_labels', true)
            ? MediaQuery.textScalerOf(context).scale(footerLabelSize) * 1.6 +
                  footer.number('icon_label_gap', 3).clamp(0, 12)
            : 0) +
        8;
    final footerHeight = footer.number('height', 64).clamp(48, 100).toDouble();
    final requiredHeight = minimumRowHeight * rowCount;
    final Color activeColor = _cmsColor(
      footer.string('active_color', '#1F6F61'),
      MobiShopColors.primaryDark,
    );
    final Color inactiveColor = _cmsColor(
      footer.string('inactive_color', '#6B7280'),
      MobiShopColors.textSecondary,
    );
    final Color backgroundColor = _cmsColor(
      footer.string('background_color', '#FFFFFF'),
      MobiShopColors.surface,
    );
    return Scaffold(
      body: NotificationListener<ScrollUpdateNotification>(
        onNotification: (ScrollUpdateNotification notification) {
          if (!footer.boolean('hide_on_scroll', false) ||
              notification.metrics.axis != Axis.vertical ||
              notification.scrollDelta == null) {
            return false;
          }
          final bool hidden = notification.scrollDelta! > 0;
          if (hidden != _footerHidden) setState(() => _footerHidden = hidden);
          return false;
        },
        child: widget.navigationShell,
      ),
      bottomNavigationBar:
          waitingForLayout ||
              !footer.enabled ||
              (_footerHidden && footer.boolean('hide_on_scroll', false)) ||
              visibleItems.isEmpty ||
              (page == 'product' &&
                  footer.string('style', 'navigation') == 'product_action')
          ? null
          : SafeArea(
              top: false,
              bottom: !AppConfig.isCmsPreview || footer.boolean('safe_area', true),
              minimum: const EdgeInsets.only(bottom: 6),
              child: Padding(
                padding: EdgeInsets.only(
                  top:
                      footer.number('margin_top', 0).clamp(0, 80) +
                      footer.number('space_up', 0).clamp(0, 80),
                  bottom:
                      footer.number('margin_bottom', 0).clamp(0, 80) +
                      footer.number('space_down', 0).clamp(0, 80),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    border: Border(
                      top: BorderSide(
                        color: _cmsColor(
                          footer.string('border_color', '#E2E6E4'),
                          MobiShopColors.divider,
                        ),
                        width: footer.number('border_width', 1),
                      ),
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(footer.number('top_radius', 0)),
                    ),
                    boxShadow: footer.string('shadow', 'subtle') == 'none'
                        ? null
                        : <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha:
                                    footer.string('shadow', 'subtle') ==
                                        'strong'
                                    ? .18
                                    : .08,
                              ),
                              blurRadius:
                                  footer.string('shadow', 'subtle') == 'strong'
                                  ? 16
                                  : 6,
                            ),
                          ],
                  ),
                  child: Padding(
                    key: const Key('cms-bottom-navigation'),
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          MediaQuery.sizeOf(context).width *
                              footer
                                  .number('side_spacing_percent', 5)
                                  .clamp(0, 25) /
                              100 +
                          footer.number('horizontal_padding', 0).clamp(0, 32),
                    ),
                    child: SizedBox(
                      key: const Key('cms-bottom-navigation-size'),
                      height: footerHeight < requiredHeight
                          ? requiredHeight
                          : footerHeight,
                      child: _footerGrid(placements, visibleItems, (entry) {
                        final item = entry.value;
                        final selected =
                            entry.key == widget.navigationShell.currentIndex;
                        final color = selected ? activeColor : inactiveColor;
                        return InkWell(
                          key: Key('cms-bottom-nav-${item.id}'),
                          onTap: () => _openBranch(ref, entry.key),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              _NavigationIcon(
                                boxKey: Key(
                                  'cms-bottom-nav-icon-box-${item.id}',
                                ),
                                icon: _footerIcon(footer, item, selected),
                                color: color,
                                size: footerIconSize,
                                boxSize: footerIconBoxSize,
                              ),
                              if (footer.boolean(
                                'show_labels',
                                true,
                              )) ...<Widget>[
                                SizedBox(
                                  key: Key(
                                    'cms-bottom-nav-icon-label-gap-${item.id}',
                                  ),
                                  height: footer
                                      .number('icon_label_gap', 3)
                                      .clamp(0, 12),
                                ),
                                SizedBox(
                                  key: Key(
                                    'cms-bottom-nav-label-box-${item.id}',
                                  ),
                                  height: MediaQuery.textScalerOf(context).scale(footerLabelSize) * 1.6,
                                  child: Center(
                                    child: Text(
                                      _footerLabel(footer, item),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: color,
                                        fontSize: footerLabelSize,
                                        fontFamily: footerFontFamily,
                                        height: 1.3,
                                        fontWeight: selected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _footerGrid(
    List<_FooterPlacement> placements,
    List<MapEntry<int, _NavigationItem>> visibleItems,
    Widget Function(MapEntry<int, _NavigationItem>) tile,
  ) {
    final entries = {for (final entry in visibleItems) entry.value.id: entry};
    final rows = placements.map((p) => p.row).toSet();
    return Column(
      children: [
        for (final row in rows)
          Expanded(
            child: Row(
              key: Key('cms-footer-row-$row'),
              children: [
                for (final placement in placements.where((p) => p.row == row))
                  Expanded(
                    flex: (placement.width * 100).round().clamp(1, 10000),
                    child: entries[placement.id] == null
                        ? const SizedBox.shrink()
                        : tile(entries[placement.id]!),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<_FooterPlacement> _footerPlacements(CmsPageComponent footer) {
    final json = footer.json('layout_json');
    final rawRows = json['rows'];
    if (rawRows is List && rawRows.isNotEmpty) {
      final result = <_FooterPlacement>[];
      final seen = <String>{};
      for (final indexed in rawRows.take(3).indexed) {
        final rawRow = indexed.$2;
        if (rawRow is! Map || rawRow['columns'] is! List) continue;
        final columns = rawRow['columns'] as List;
        for (final column in columns.take(6)) {
          if (column is! Map) continue;
          final parsed = double.tryParse('${column['width']}');
          final width = parsed != null && parsed.isFinite && parsed > 0
              ? parsed
              : 100 / columns.length;
          final items = column['items'] is List
              ? (column['items'] as List)
                    .map((item) => '$item')
                    .where(
                      (id) =>
                          _items.any((item) => item.id == id) && seen.add(id),
                    )
                    .toList()
              : <String>[];
          if (items.isEmpty) {
            result.add(_FooterPlacement('', width, indexed.$1));
          } else {
            for (final id in items) {
              result.add(
                _FooterPlacement(id, width / items.length, indexed.$1),
              );
            }
          }
        }
      }
      if (result.isNotEmpty) return result;
    }
    final legacyItems = json['items'];
    final ids = legacyItems is List
        ? legacyItems.map((item) => '$item').toSet().toList()
        : _items.take(4).map((item) => item.id).toList();
    return ids.map((id) => _FooterPlacement(id, 100 / ids.length, 0)).toList();
  }

  IconData _footerIcon(
    CmsPageComponent footer,
    _NavigationItem item,
    bool selected,
  ) {
    final String variant = footer.string('${item.id}_icon_variant', '');
    if (AppConfig.isCmsPreview &&
        _usesApplicationFooterIcon(item.id, variant)) {
      return selected ? item.selectedIcon : item.icon;
    }
    return switch (item.id) {
      'home' =>
        variant == 'filled' || selected
            ? Icons.home_rounded
            : variant == 'rounded'
            ? Icons.other_houses_outlined
            : Icons.home_outlined,
      'categories' =>
        variant == 'list'
            ? Icons.view_list_outlined
            : variant == 'category'
            ? Icons.category_outlined
            : selected
            ? Icons.grid_view_rounded
            : Icons.grid_view_outlined,
      'wishlist' =>
        variant == 'bookmark'
            ? (selected ? Icons.bookmark : Icons.bookmark_border)
            : selected
            ? Icons.favorite_rounded
            : Icons.favorite_border_rounded,
      'account' =>
        variant == 'profile'
            ? Icons.manage_accounts_outlined
            : variant == 'circle'
            ? Icons.account_circle_outlined
            : selected
            ? Icons.person_rounded
            : Icons.person_outline_rounded,
      'search' =>
        variant == 'classic'
            ? Icons.search
            : variant == 'minimal'
            ? Icons.manage_search_outlined
            : Icons.search_rounded,
      'cart' =>
        variant == 'cart'
            ? Icons.shopping_cart_outlined
            : variant == 'basket'
            ? Icons.shopping_basket_outlined
            : Icons.shopping_bag_outlined,
      'orders' =>
        variant == 'box'
            ? Icons.inventory_2_outlined
            : variant == 'list'
            ? Icons.format_list_bulleted_rounded
            : Icons.receipt_long_outlined,
      _ => selected ? item.selectedIcon : item.icon,
    };
  }

  bool _usesApplicationFooterIcon(String item, String variant) {
    final String normalized = variant.trim();
    return normalized.isEmpty ||
        switch (item) {
          'home' => normalized == 'home',
          'categories' => normalized == 'grid',
          'wishlist' => normalized == 'heart' || normalized == 'rounded',
          'account' => normalized == 'person',
          _ => false,
        };
  }

  String _footerLabel(CmsPageComponent footer, _NavigationItem item) {
    final String configured = footer.string('${item.id}_label', '').trim();
    final String english = switch (item.id) {
      'home' => 'Home',
      'categories' => 'Categories',
      'wishlist' => 'Wishlist',
      'account' => 'Account',
      'search' => 'Search',
      'cart' => 'Cart',
      'orders' => 'Orders',
      _ => item.label,
    };
    final bool arabic = Localizations.localeOf(context).languageCode == 'ar';
    return cmsFooterLabel(configured, arabic ? item.label : english, <String>[
      english,
      item.label,
    ]);
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
    return widget.navigationShell.currentIndex == 0
        ? 'home'
        : widget.navigationShell.currentIndex == 1
        ? 'category'
        : widget.navigationShell.currentIndex == 2
        ? 'wishlist'
        : widget.navigationShell.currentIndex == 3
        ? 'account'
        : 'catalog';
  }

  void _openBranch(WidgetRef ref, int index) {
    if (index >= 4) {
      final route = switch (_items[index].id) {
        'search' => '/search',
        'cart' => '/cart',
        'orders' => '/orders',
        _ => null,
      };
      if (route != null) context.push(route);
      return;
    }
    if (index == 0 && !AppConfig.isCmsPreview) {
      ref.invalidate(homeLayoutProvider);
    }
    if (index == 1) {
      ref.read(categoryEntryRevisionProvider.notifier).enter();
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation:
          index == 1 || index == widget.navigationShell.currentIndex,
    );
  }
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({
    required this.boxKey,
    required this.icon,
    required this.color,
    required this.size,
    required this.boxSize,
  });

  final Key boxKey;
  final IconData icon;
  final Color color;
  final double size;
  final double boxSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: boxKey,
      dimension: boxSize,
      child: Center(
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}

Color _cmsColor(String value, Color fallback) {
  final String normalized = value.replaceFirst('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized)) return fallback;
  return Color(int.parse('FF$normalized', radix: 16));
}

class _FooterPlacement {
  const _FooterPlacement(this.id, this.width, this.row);
  final int row;

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
