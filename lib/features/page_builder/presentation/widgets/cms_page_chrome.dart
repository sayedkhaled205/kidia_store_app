import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

typedef CmsPageLayoutWidgetBuilder = Widget Function(
  BuildContext context,
  CmsPageLayout layout,
);

class CmsPageLayoutLoader extends ConsumerWidget {
  const CmsPageLayoutLoader({
    required this.page,
    required this.builder,
    super.key,
  });

  final String page;
  final CmsPageLayoutWidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CmsPageLayout> state = ref.watch(
      cmsPageLayoutProvider(page),
    );
    return builder(context, state.value ?? CmsPageLayout.fallback(page));
  }
}

class CmsPageHeaderAction {
  const CmsPageHeaderAction({
    required this.type,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.key,
    this.color,
  });

  final String type;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Key? key;
  final Color? color;
}

class CmsPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CmsPageAppBar({
    required this.layout,
    required this.defaultTitle,
    super.key,
    this.actions = const <CmsPageHeaderAction>[],
  });

  final CmsPageLayout layout;
  final String defaultTitle;
  final List<CmsPageHeaderAction> actions;

  CmsPageComponent get _header => layout.header;

  @override
  Size get preferredSize => Size.fromHeight(
    _header.enabled ? _header.number('height', 64).clamp(48, 120) : 0,
  );

  @override
  Widget build(BuildContext context) {
    if (!_header.enabled) return const SizedBox.shrink();
    final Color background = _color(_header.string('background_color', '#FFFFFF'), Theme.of(context).colorScheme.surface);
    final Color foreground = _color(_header.string('icon_color', '#1F2933'), Theme.of(context).colorScheme.onSurface);
    final List<Map<String, dynamic>> rows = _layoutRows();
    final double padding = _header.number('horizontal_padding', 16).clamp(0, 32);
    return Material(
      color: _header.string('style', 'standard') == 'transparent' ? background.withValues(alpha: 0) : background,
      elevation: _header.string('shadow', 'subtle') == 'none' ? 0 : _header.string('shadow', 'subtle') == 'strong' ? 6 : 2,
	  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_header.number('corner_radius', 0)), side: BorderSide(color: _color(_header.string('border_color', '#E2E6E4'), Colors.transparent), width: _header.number('border_width', 0))),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: preferredSize.height,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: _header.number('vertical_padding', 8).clamp(0, 24)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: rows.indexed.expand((entry) sync* {
                if (entry.$1 > 0) {
                  yield SizedBox(height: _header.number('row_gap', 8).clamp(0, 24));
                }
                yield _headerRow(context, entry.$2, foreground);
              }).toList(growable: false),
            ),
          ),
        ),
      ),
    );
  }

  Widget _headerRow(BuildContext context, Map<String, dynamic> row, Color color) {
    final List<Map<String, dynamic>> columns = _columns(row);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: columns.map((column) {
          final double width = (column['width'] as num?)?.toDouble() ?? (100 / columns.length);
          final String align = '${column['align'] ?? 'center'}';
          return Expanded(
            flex: (width * 100).round().clamp(1, 10000).toInt(),
            child: _slot(
              context,
              column['items'],
              align == 'left' ? Alignment.centerLeft : align == 'right' ? Alignment.centerRight : Alignment.center,
              color,
            ),
          );
        }).toList(growable: false),
      ),
    );
  }

  List<Map<String, dynamic>> _columns(Map<String, dynamic> row) {
    final dynamic rawColumns = row['columns'];
    if (rawColumns is List) {
      final List<Map<String, dynamic>> columns = rawColumns
          .whereType<Map>()
          .map((column) => Map<String, dynamic>.from(column))
          .take(6)
          .toList(growable: false);
      if (columns.isNotEmpty) return columns;
    }
    // Backward compatibility for layouts saved before the percentage-column schema.
    return <Map<String, dynamic>>[
      <String, dynamic>{'width': 33.33, 'align': 'left', 'items': row['left'] ?? <String>[]},
      <String, dynamic>{'width': 33.34, 'align': 'center', 'items': row['center'] ?? <String>[]},
      <String, dynamic>{'width': 33.33, 'align': 'right', 'items': row['right'] ?? <String>[]},
    ];
  }

  List<Map<String, dynamic>> _layoutRows() {
    final dynamic raw = _header.json('layout_json')['rows'];
    if (raw is List) {
      final rows = raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).take(3).toList();
      if (rows.isNotEmpty) return rows;
    }
    if (layout.page == 'product') {
      return <Map<String, dynamic>>[<String, dynamic>{
        'left': <String>['back'],
        'center': <String>['title'],
        'right': <String>['cart', 'wishlist'],
      }];
    }
    return <Map<String, dynamic>>[<String, dynamic>{'left': <String>[], 'center': <String>['title'], 'right': <String>['search', 'cart']}];
  }

  Widget _slot(BuildContext context, dynamic rawItems, Alignment alignment, Color color) {
    final List<String> items = rawItems is List ? rawItems.map((item) => '$item').toList() : <String>[];
    if (items.length == 1 && items.first == 'search_bar') {
      return Align(
        alignment: alignment,
        child: FractionallySizedBox(
          widthFactor: _header.number('search_width_percent', 100).clamp(30, 100) / 100,
          child: _searchBar(context, _actionFor('search'), color),
        ),
      );
    }
    return Align(
      alignment: alignment,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: alignment,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: items.map((item) => Padding(
            padding: EdgeInsets.symmetric(horizontal: _header.number('icon_gap', 6).clamp(0, 24) / 2),
            child: _item(context, item, color),
          )).toList(growable: false),
        ),
      ),
    );
  }

  Widget _item(BuildContext context, String item, Color color) {
    if (item == 'title') return Text(_header.string('title', defaultTitle), key: const Key('commerce-app-bar-title'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _color(_header.string('title_color', '#1F2933'), color), fontWeight: FontWeight.w700));
    if (item == 'subtitle') return Text(_header.string('subtitle', ''), maxLines: 1, overflow: TextOverflow.ellipsis);
    if (item == 'logo') {
      final String url = _header.string('logo_url', '');
      return url.isEmpty ? Text('Kidia', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 20)) : Image.network(url, width: _header.number('logo_width', 118), height: _header.number('logo_height', 38), fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox.shrink());
    }
    final CmsPageHeaderAction? action = item == 'back'
        ? CmsPageHeaderAction(type: 'back', icon: Icons.arrow_back_rounded, tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: () => Navigator.of(context).maybePop())
        : _actionFor(item == 'search_bar' ? 'search' : item);
    if (item == 'search_bar') return _searchBar(context, action, color);
    if (action == null) return const SizedBox.shrink();
    return _actionButton(context, action, color);
  }

  Widget _searchBar(BuildContext context, CmsPageHeaderAction? action, Color color) => InkWell(
    onTap: action?.onPressed,
    borderRadius: BorderRadius.circular(_header.number('search_radius', 14)),
    child: Container(
      constraints: const BoxConstraints(minWidth: 120),
      height: _header.number('search_height', 40).clamp(32, 64),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: _color(_header.string('search_background', '#F1F3F4'), Theme.of(context).colorScheme.surfaceContainerHighest), borderRadius: BorderRadius.circular(_header.number('search_radius', 14)), border: Border.all(color: _color(_header.string('search_border_color', '#DDE3E8'), Colors.transparent), width: _header.number('search_border_width', 0))),
      child: Row(children: <Widget>[Icon(_iconFor('search', _header.string('search_icon_variant', 'rounded'), false), size: _header.number('search_icon_size', 24).clamp(16, 40), color: _color(_header.string('search_icon_color', '#1F2933'), color)), const SizedBox(width: 8), Expanded(child: Text(_header.string('search_placeholder', 'Search products'), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _color(_header.string('search_text_color', '#5F6368'), color)))), if (_header.boolean('show_voice_search', false)) Icon(Icons.mic_none_rounded, size: _header.number('search_icon_size', 24).clamp(16, 40), color: _color(_header.string('search_icon_color', '#1F2933'), color))]),
    ),
  );

  Widget _actionButton(BuildContext context, CmsPageHeaderAction action, Color fallbackColor) {
    final String prefix = action.type == 'search' ? 'search_icon' : action.type == 'account' ? 'account_icon' : action.type;
    final String style = _header.string('${prefix}_style', action.type == 'account' ? _header.string('account_style', 'icon') : 'outline');
    final Color color = action.color ?? _color(_header.string('${prefix}_color', _header.string('icon_color', '#1F2933')), fallbackColor);
    final Color background = _color(_header.string('${prefix}_background', '#FFFFFF'), Colors.transparent);
    final double size = _header.number('${prefix}_size', _header.number('icon_size', 24)).clamp(14, 40);
    final double radius = _header.number('${prefix}_radius', 12).clamp(0, 24);
    final bool selectedWishlist = action.type == 'wishlist' && action.icon == Icons.favorite_rounded;
    final IconData icon = _iconFor(action.type, _header.string('${action.type}_icon_variant', ''), style == 'filled' || selectedWishlist);
    return IconButton(
      key: action.key,
      tooltip: action.tooltip,
      onPressed: action.onPressed,
      style: IconButton.styleFrom(
        backgroundColor: style == 'circle' || style == 'filled' ? background : Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      color: color,
      icon: Icon(icon, size: size),
    );
  }

  IconData _iconFor(String type, String variant, bool filled) => switch (type) {
    'back' => variant == 'chevron' ? Icons.chevron_left_rounded : variant == 'rounded' ? Icons.keyboard_backspace_rounded : Icons.arrow_back_rounded,
    'search' => variant == 'classic' ? Icons.search : variant == 'minimal' ? Icons.manage_search_outlined : Icons.search_rounded,
    'cart' => variant == 'cart' ? (filled ? Icons.shopping_cart : Icons.shopping_cart_outlined) : variant == 'basket' ? (filled ? Icons.shopping_basket : Icons.shopping_basket_outlined) : (filled ? Icons.shopping_bag : Icons.shopping_bag_outlined),
    'wishlist' => variant == 'bookmark' ? (filled ? Icons.bookmark : Icons.bookmark_border) : (filled ? Icons.favorite_rounded : Icons.favorite_border_rounded),
    'account' => variant == 'circle' ? Icons.account_circle_outlined : variant == 'profile' ? Icons.manage_accounts_outlined : (filled ? Icons.person : Icons.person_outline_rounded),
    'orders' => variant == 'box' ? Icons.inventory_2_outlined : variant == 'list' ? Icons.format_list_bulleted_rounded : Icons.receipt_long_outlined,
    'support' => variant == 'chat' ? Icons.chat_bubble_outline_rounded : variant == 'support' ? Icons.support_agent_rounded : Icons.headset_mic_outlined,
    'menu' => variant == 'dots' ? Icons.more_horiz_rounded : variant == 'grid' ? Icons.grid_view_rounded : Icons.menu_rounded,
    _ => _actionFor(type)?.icon ?? Icons.circle_outlined,
  };

  CmsPageHeaderAction? _actionFor(String type) {
    for (final CmsPageHeaderAction action in actions) { if (action.type == type) return action; }
    return null;
  }
}

Color _color(String value, Color fallback) {
  final String normalized = value.replaceFirst('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$').hasMatch(normalized)) {
    return fallback;
  }
  final String argb = normalized.length == 6 ? 'FF$normalized' : normalized;
  return Color(int.parse(argb, radix: 16));
}
