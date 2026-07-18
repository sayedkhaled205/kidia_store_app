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
    if (!_header.enabled) {
      return const SizedBox.shrink();
    }
    final Color background = _color(
      _header.string('background_color', '#FFFFFF'),
      Theme.of(context).colorScheme.surface,
    );
    final Color titleColor = _color(
      _header.string('title_color', '#1F2933'),
      Theme.of(context).colorScheme.onSurface,
    );
    final String searchStyle = _header.string('search_style', 'icon');
    final bool showSearchBar =
        searchStyle == 'bar' && _header.boolean('show_search', true);
    CmsPageHeaderAction? searchAction;
    for (final CmsPageHeaderAction action in actions) {
      if (action.type == 'search') {
        searchAction = action;
        break;
      }
    }
    final List<Widget> visibleActions = actions
        .where((CmsPageHeaderAction action) {
          if (action.type == 'search' && showSearchBar) {
            return false;
          }
          return _header.boolean('show_${action.type}', true);
        })
        .map((CmsPageHeaderAction action) => _actionButton(context, action, titleColor))
        .toList(growable: false);
    return AppBar(
      centerTitle: true,
      toolbarHeight: preferredSize.height,
      elevation: _header.string('shadow', 'subtle') == 'none' ? 0 : 2,
      backgroundColor: _header.string('style', 'standard') == 'transparent'
          ? background.withValues(alpha: 0)
          : background,
      foregroundColor: titleColor,
      automaticallyImplyLeading: false,
      leading: _header.boolean('show_back', true) && Navigator.of(context).canPop()
          ? _actionButton(
              context,
              CmsPageHeaderAction(type: 'back', icon: Icons.arrow_back_rounded, tooltip: MaterialLocalizations.of(context).backButtonTooltip, onPressed: () => Navigator.of(context).maybePop()),
              titleColor,
            )
          : null,
      title: showSearchBar
          ? InkWell(
              borderRadius: BorderRadius.circular(
                _header.number('search_radius', 14),
              ),
              onTap: searchAction?.onPressed,
              child: Container(
                height: _header.number('search_height', 40).clamp(32, 64),
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _color(
                    _header.string('search_background', '#F1F3F4'),
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  borderRadius: BorderRadius.circular(
                    _header.number('search_radius', 14),
                  ),
                  border: Border.all(
                    color: _color(
                      _header.string('search_border_color', '#DDE3E8'),
                      Colors.transparent,
                    ),
                    width: _header.number('search_border_width', 0),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.search_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _header.string('search_placeholder', 'Search products'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _color(
                            _header.string('search_text_color', '#5F6368'),
                            titleColor,
                          ),
                        ),
                      ),
                    ),
                    if (_header.boolean('show_voice_search', false))
                      const Icon(Icons.mic_none_rounded, size: 20),
                  ],
                ),
              ),
            )
          : Text(
              _header.string('title', defaultTitle),
              key: const Key('commerce-app-bar-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      actions: visibleActions,
    );
  }

  Widget _actionButton(BuildContext context, CmsPageHeaderAction action, Color fallbackColor) {
    final String prefix = action.type == 'search' ? 'search_icon' : action.type == 'account' ? 'account_icon' : action.type;
    final String style = _header.string('${prefix}_style', action.type == 'account' ? _header.string('account_style', 'icon') : 'outline');
    final Color color = action.color ?? _color(_header.string('${prefix}_color', '#1F2933'), fallbackColor);
    final Color background = _color(_header.string('${prefix}_background', '#FFFFFF'), Colors.transparent);
    final double size = _header.number('${prefix}_size', 24).clamp(16, 40);
    final double radius = _header.number('${prefix}_radius', 12).clamp(0, 24);
    IconData icon = action.icon;
    if (style == 'filled') {
      icon = switch (action.type) {
        'cart' => Icons.shopping_bag_rounded,
        'wishlist' => Icons.favorite_rounded,
        'account' => Icons.person_rounded,
        _ => action.icon,
      };
    }
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
}

Color _color(String value, Color fallback) {
  final String normalized = value.replaceFirst('#', '');
  if (!RegExp(r'^[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$').hasMatch(normalized)) {
    return fallback;
  }
  final String argb = normalized.length == 6 ? 'FF$normalized' : normalized;
  return Color(int.parse(argb, radix: 16));
}
