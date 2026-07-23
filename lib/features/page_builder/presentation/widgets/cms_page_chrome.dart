import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

typedef CmsPageLayoutWidgetBuilder = Widget Function(
  BuildContext context,
  CmsPageLayout layout,
);

class CmsElementFrame extends StatelessWidget {
  const CmsElementFrame({required this.component, required this.child, super.key});

  final CmsPageComponent component;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final String raw = component.string('background_color', '#FFFFFF').trim();
    final Color background = _color(raw, Colors.white);
    final double mergeUp = component
        .number('margin_top', 0)
        .clamp(0, 80)
        .toDouble();
    final double mergeDown = component
        .number('margin_bottom', 0)
        .clamp(0, 80)
        .toDouble();
    return Transform.translate(
      offset: Offset(0, mergeDown - mergeUp),
      child: Material(
        color: background,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: component
                .number('padding_horizontal', 0)
                .clamp(0, 40)
                .toDouble(),
            vertical: component
                .number('padding_vertical', 0)
                .clamp(0, 40)
                .toDouble(),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: component.number('space_up', 0).clamp(0, 80).toDouble(),
              bottom: component
                  .number('space_down', 0)
                  .clamp(0, 80)
                  .toDouble(),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

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
    final CmsPageLayout? resolved = state.value;
    if (resolved != null) {
      return builder(context, resolved);
    }
    if (state.hasError) {
      return builder(context, CmsPageLayout.fallback(page));
    }
    return const Scaffold(
      body: SafeArea(
        child: Center(child: CircularProgressIndicator()),
      ),
    );
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

class CmsPageScaffold extends StatefulWidget {
  const CmsPageScaffold({
    required this.layout,
    required this.defaultTitle,
    required this.body,
    super.key,
    this.actions = const <CmsPageHeaderAction>[],
    this.bottomNavigationBar,
    this.backgroundColor,
    this.scrollController,
  });

  final CmsPageLayout layout;
  final String defaultTitle;
  final Widget body;
  final List<CmsPageHeaderAction> actions;
  final Widget? bottomNavigationBar;
  final Color? backgroundColor;
  final ScrollController? scrollController;

  @override
  State<CmsPageScaffold> createState() => _CmsPageScaffoldState();
}

class _CmsPageScaffoldState extends State<CmsPageScaffold> {
  static const double _collapseThreshold = 32;
  static const double _expandThreshold = 8;

  bool _collapsed = false;
  double _collapseProgress = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_handleControllerScroll);
  }

  void _handleControllerScroll() {
    final ScrollController? controller = widget.scrollController;
    if (controller == null || !controller.hasClients) return;
    _updateCollapsed(controller.position.extentBefore);
  }

  void _updateCollapsed(double extentBefore) {
    final bool enabled = widget.layout.header.boolean(
      'collapse_on_scroll',
      false,
    );
    final bool next = enabled && (_collapsed
        ? extentBefore > _expandThreshold
        : extentBefore > _collapseThreshold);
    final bool scrollLinked =
        widget.layout.header.string('collapse_transition', 'smooth_compact') ==
        'smooth_compact';
    final double collapseDistance = switch (
      widget.layout.header.string('collapse_speed', 'medium')
    ) {
      'fast' => 44,
      'slow' => 96,
      _ => 64,
    };
    final double nextProgress = enabled
        ? (extentBefore / collapseDistance).clamp(0, 1).toDouble()
        : 0;
    if (next != _collapsed ||
        (scrollLinked && (nextProgress - _collapseProgress).abs() > .001)) {
      setState(() {
        _collapsed = next;
        _collapseProgress = scrollLinked
            ? nextProgress
            : (next ? 1 : 0);
      });
    }
  }

  bool _handleScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }
    final ScrollController? controller = widget.scrollController;
    if (controller != null && controller.hasClients) {
      _updateCollapsed(controller.position.extentBefore);
    } else {
      _updateCollapsed(notification.metrics.extentBefore);
    }
    return false;
  }

  @override
  void didUpdateWidget(covariant CmsPageScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_handleControllerScroll);
      widget.scrollController?.addListener(_handleControllerScroll);
    }
    if (oldWidget.layout.page != widget.layout.page ||
        !widget.layout.header.boolean('collapse_on_scroll', false)) {
      _collapsed = false;
      _collapseProgress = 0;
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_handleControllerScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool collapsed =
        widget.layout.header.boolean('collapse_on_scroll', false) && _collapsed;
    final String transition = widget.layout.header.string(
      'collapse_transition',
      'smooth_compact',
    );
    final double compactHeight = widget.layout.header
        .number('compact_height', 60)
        .clamp(44, 100);
    final double compactContentHeight =
        widget.layout.header.number('search_height', 40).clamp(32, 64) +
        (widget.layout.header.number('vertical_padding', 8).clamp(0, 24) * 2);
    final bool needsCompactSearchRoom = transition == 'smooth_compact';
    final double regularHeight = widget.layout.header
        .number('height', 64)
        .clamp(48, 120);
    final double resolvedCompactHeight =
        needsCompactSearchRoom && compactHeight < compactContentHeight
        ? compactContentHeight
        : compactHeight;
    final double targetHeight = transition == 'smooth_compact'
        ? regularHeight +
              ((resolvedCompactHeight - regularHeight) * _collapseProgress)
        : (collapsed ? resolvedCompactHeight : regularHeight);
    final Duration duration = transition == 'instant'
        ? Duration.zero
        : switch (widget.layout.header.string('collapse_speed', 'medium')) {
            'fast' => const Duration(milliseconds: 160),
            'slow' => const Duration(milliseconds: 420),
            _ => const Duration(milliseconds: 260),
          };
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: targetHeight),
      duration: transition == 'smooth_compact' ? Duration.zero : duration,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double animatedHeight, Widget? child) =>
          Scaffold(
            backgroundColor: widget.backgroundColor,
            appBar: CmsPageAppBar(
              layout: widget.layout,
              defaultTitle: widget.defaultTitle,
              actions: widget.actions,
              compact: collapsed,
              collapseProgress: transition == 'smooth_compact'
                  ? _collapseProgress
                  : (collapsed ? 1 : 0),
              visibleHeight: animatedHeight,
            ),
            body: NotificationListener<ScrollNotification>(
              onNotification: _handleScroll,
              child: widget.body,
            ),
            bottomNavigationBar: widget.bottomNavigationBar,
          ),
    );
  }
}

class CmsPageAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CmsPageAppBar({
    required this.layout,
    required this.defaultTitle,
    super.key,
    this.actions = const <CmsPageHeaderAction>[],
    this.compact = false,
    this.collapseProgress,
    this.visibleHeight,
  });

  final CmsPageLayout layout;
  final String defaultTitle;
  final List<CmsPageHeaderAction> actions;
  final bool compact;
  final double? collapseProgress;
  final double? visibleHeight;

  CmsPageComponent get _header => layout.header;

  @override
  Size get preferredSize => Size.fromHeight(_header.enabled
      ? _visibleHeight +
          _header.number('margin_top', 0).clamp(0, 80) +
          _header.number('margin_bottom', 0).clamp(0, 80) +
          _header.number('space_up', 0).clamp(0, 80) +
          _header.number('space_down', 0).clamp(0, 80)
      : 0);

  double get _visibleHeight {
    if (visibleHeight != null) return visibleHeight!;
    if (!compact) return _header.number('height', 64).clamp(48, 120);
    final double configured = _header
        .number('compact_height', 60)
        .clamp(44, 100);
    if (_header.string('collapse_transition', 'smooth_compact') !=
        'smooth_compact') {
      return configured;
    }
    final double required =
        _header.number('search_height', 40).clamp(32, 64) +
        (_header.number('vertical_padding', 8).clamp(0, 24) * 2);
    return configured < required ? required : configured;
  }

  @override
  Widget build(BuildContext context) {
    if (!_header.enabled) return const SizedBox.shrink();
    final String compactStyle = _header.string('compact_style', 'standard');
    final String transition = _header.string(
      'collapse_transition',
      'smooth_compact',
    );
    final Duration transitionDuration = _transitionDuration(transition);
    final Color regularBackground = _color(
      _header.string('background_color', '#FFFFFF'),
      Theme.of(context).colorScheme.surface,
    );
    final Color compactBackground = compactStyle == 'transparent'
        ? Colors.transparent
        : _color(
            _header.string('compact_background_color', '#FFFFFF'),
            Theme.of(context).colorScheme.surface,
          );
    final Color foreground = _color(
      _header.string('icon_color', '#1F2933'),
      Theme.of(context).colorScheme.onSurface,
    );
    final List<Map<String, dynamic>> rows = compact
        ? _compactLayoutRows()
        : _layoutRows();
    final double progress = (collapseProgress ?? (compact ? 1 : 0))
        .clamp(0, 1)
        .toDouble();
    final double regularPadding = _header
        .number('horizontal_padding', 16)
        .clamp(0, 32);
    final double compactPadding = _header
        .number('compact_horizontal_padding', 16)
        .clamp(0, 32);
    final double padding = _lerp(regularPadding, compactPadding, progress);
    final double configuredSideMargin = _header
        .number(
          'compact_side_margin',
          compactStyle == 'floating' || compactStyle == 'pill' ? 8 : 0,
        )
        .clamp(0, 32);
    final double sideMargin = _lerp(0, configuredSideMargin, progress);
    final double regularRadius = _header.number('corner_radius', 0);
    final double compactRadius = _header
        .number(
          'compact_radius',
          compactStyle == 'pill'
              ? 40
              : compactStyle == 'floating'
              ? 16
              : 0,
        )
        .clamp(0, 40);
    final double radius = _lerp(regularRadius, compactRadius, progress);
    final String regularShadow = _header.string('shadow', 'subtle');
    final String compactShadow = _header.string(
      'compact_shadow',
      compactStyle == 'transparent' ? 'none' : 'subtle',
    );
    final double elevation = _lerp(
      _shadowElevation(regularShadow),
      _shadowElevation(compactShadow),
      progress,
    );
    final Color background = transition == 'smooth_compact'
        ? Color.lerp(regularBackground, compactBackground, progress)!
        : (compact ? compactBackground : regularBackground);
    final Color regularBorder = _color(
      _header.string('border_color', '#E2E6E4'),
      Colors.transparent,
    );
    final Color compactBorder = _color(
      _header.string('compact_border_color', '#E2E6E4'),
      Colors.transparent,
    );
    final Color borderColor = transition == 'smooth_compact'
        ? Color.lerp(regularBorder, compactBorder, progress)!
        : (compact ? compactBorder : regularBorder);
    final double borderWidth = _lerp(
      _header.number('border_width', 0),
      _header.number('compact_border_width', 0),
      progress,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        sideMargin,
        _header.number('margin_top', 0).clamp(0, 80) +
            _header.number('space_up', 0).clamp(0, 80),
        sideMargin,
        _header.number('margin_bottom', 0).clamp(0, 80) +
            _header.number('space_down', 0).clamp(0, 80),
      ),
      child: Material(
        color:
            (!compact &&
                _header.string('style', 'standard') == 'transparent')
            ? background.withValues(alpha: 0)
            : background,
        elevation: elevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(
            color: borderColor,
            width: borderWidth,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: _visibleHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: padding,
                vertical: _header.number('vertical_padding', 8).clamp(0, 24),
              ),
              child: ClipRect(
                child: transition == 'smooth_compact'
                    ? Stack(
                        key: const Key('cms-page-app-bar-scroll-transition'),
                        alignment: Alignment.center,
                        children: <Widget>[
                          _scrollLinkedContent(
                            context,
                            rows: _layoutRows(),
                            color: foreground,
                            width: MediaQuery.sizeOf(context).width -
                                (sideMargin * 2) -
                                (padding * 2),
                            opacity: 1 - progress,
                            translateY: -24 * progress,
                          ),
                          _scrollLinkedContent(
                            context,
                            rows: _compactLayoutRows(),
                            color: foreground,
                            width: MediaQuery.sizeOf(context).width -
                                (sideMargin * 2) -
                                (padding * 2),
                            opacity: progress,
                            translateY: 14 * (1 - progress),
                          ),
                        ],
                      )
                    : AnimatedSwitcher(
                  key: const Key('cms-page-app-bar-transition'),
                  duration: transitionDuration,
                  reverseDuration: transitionDuration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) =>
                          _transitionBuilder(transition, child, animation),
                  child: FittedBox(
                    key: ValueKey<bool>(compact),
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: (MediaQuery.sizeOf(context).width -
                              (sideMargin * 2) -
                              (padding * 2))
                          .clamp(1, double.infinity)
                          .toDouble(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: rows.indexed.expand((entry) sync* {
                          if (entry.$1 > 0) {
                            yield SizedBox(
                              height: _header.number('row_gap', 8).clamp(0, 24),
                            );
                          }
                          yield _headerRow(context, entry.$2, foreground);
                        }).toList(growable: false),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _lerp(num start, num end, double progress) =>
      start.toDouble() + ((end.toDouble() - start.toDouble()) * progress);

  double _shadowElevation(String shadow) => switch (shadow) {
    'none' => 0,
    'strong' => 6,
    _ => 2,
  };

  Widget _scrollLinkedContent(
    BuildContext context, {
    required List<Map<String, dynamic>> rows,
    required Color color,
    required double width,
    required double opacity,
    required double translateY,
  }) {
    if (opacity <= .001) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      ignoring: opacity < .5,
      child: Opacity(
        opacity: opacity.clamp(0, 1).toDouble(),
        child: Transform.translate(
          offset: Offset(0, translateY),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: SizedBox(
              width: width.clamp(1, double.infinity).toDouble(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: rows.indexed.expand((entry) sync* {
                  if (entry.$1 > 0) {
                    yield SizedBox(
                      height: _header.number('row_gap', 8).clamp(0, 24),
                    );
                  }
                  yield _headerRow(context, entry.$2, color);
                }).toList(growable: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Duration _transitionDuration(String transition) {
    if (transition == 'instant') return Duration.zero;
    return switch (_header.string('collapse_speed', 'medium')) {
      'fast' => const Duration(milliseconds: 160),
      'slow' => const Duration(milliseconds: 420),
      _ => const Duration(milliseconds: 260),
    };
  }

  Widget _transitionBuilder(
    String transition,
    Widget child,
    Animation<double> animation,
  ) {
    if (transition == 'instant') return child;
    final Animation<double> curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final bool compactChild = child.key == const ValueKey<bool>(true);
    final Animation<Offset> slide = Tween<Offset>(
      begin: transition == 'smooth_compact'
          ? Offset(0, compactChild ? 0.28 : -0.28)
          : const Offset(0, -0.22),
      end: Offset.zero,
    ).animate(curved);
    return switch (transition) {
      'fade' => FadeTransition(opacity: curved, child: child),
      'slide' => SlideTransition(position: slide, child: child),
      'scale' => FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          alignment: Alignment.topCenter,
          child: child,
        ),
      ),
      _ => FadeTransition(
        opacity: curved,
        child: SlideTransition(position: slide, child: child),
      ),
    };
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

	List<Map<String, dynamic>> _compactLayoutRows() {
		final dynamic raw = _header.json('compact_layout_json')['rows'];
		if (raw is List) {
			final rows = raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).take(1).toList();
			if (rows.isNotEmpty) return rows;
		}
		return <Map<String, dynamic>>[<String, dynamic>{'columns': <Map<String, dynamic>>[
			<String, dynamic>{'width': 84, 'align': 'left', 'items': <String>['search_bar']},
			<String, dynamic>{'width': 16, 'align': 'right', 'items': <String>['cart']},
		]}];
	}

  Widget _slot(BuildContext context, dynamic rawItems, Alignment alignment, Color color) {
    final List<String> items = rawItems is List ? rawItems.map((item) => '$item').where((item) => item != 'subtitle').toList() : <String>[];
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
    if (item == 'title') {
      String title = _header.string('title', defaultTitle);
      final String transform = _header.string('title_transform', 'none');
      if (transform == 'uppercase') {
        title = title.toUpperCase();
      } else if (transform == 'lowercase') {
        title = title.toLowerCase();
      }
      final String alignment = _header.string('title_alignment', 'center');
      final TextAlign textAlign = alignment == 'start'
          ? TextAlign.start
          : alignment == 'end'
          ? TextAlign.end
          : TextAlign.center;
      final int weight = _header.number('title_font_weight', 700).round();
      return Transform.translate(
        offset: Offset(
          _header.number('title_offset_x', 0).clamp(-40, 40).toDouble(),
          _header.number('title_offset_y', 0).clamp(-40, 40).toDouble(),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth:
                MediaQuery.sizeOf(context).width *
                _header
                    .number('title_max_width_percent', 100)
                    .clamp(20, 100) /
                100,
          ),
          child: Text(
            title,
            key: const Key('commerce-app-bar-title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: TextStyle(
              color: _color(
                _header.string('title_color', '#1F2933'),
                color,
              ),
              fontSize: _header
                  .number('title_font_size', 18)
                  .clamp(10, 42)
                  .toDouble(),
              fontWeight: FontWeight.values.firstWhere(
                (FontWeight value) => value.value == weight,
                orElse: () => FontWeight.w700,
              ),
              letterSpacing: _header
                  .number('title_letter_spacing', 0)
                  .clamp(-2, 8)
                  .toDouble(),
              height: _header
                  .number('title_line_height', 1.2)
                  .clamp(.8, 2)
                  .toDouble(),
            ),
          ),
        ),
      );
    }
    if (item == 'subtitle') return const SizedBox.shrink(); // Legacy layouts: subtitle now belongs to the logo item.
    if (item == 'logo') {
      final String url = _header.string('logo_url', '');
      final String subtitle = _header.string('subtitle', '');
      final Color logoTextColor = _color(
        _header.string('logo_text_color', '#1F2933'),
        color,
      );
      final Widget textLogo = Text(
        _header.string('logo_text', 'Kidia'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: logoTextColor,
          fontWeight: FontWeight.w900,
          fontSize: 20,
        ),
      );
      final Widget logo = url.isEmpty
          ? textLogo
          : Image.network(
              url,
              width: _header.number('logo_width', 118),
              height: _header.number('logo_height', 38),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => textLogo,
            );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          logo,
          if (subtitle.isNotEmpty)
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: logoTextColor, fontSize: 11),
            ),
        ],
      );
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
	final String backgroundKey = action.type == 'account'
	    ? 'account_background'
	    : '${prefix}_background';
	final String radiusKey = action.type == 'account'
	    ? 'account_radius'
	    : '${prefix}_radius';
    final String style = _header.string('${prefix}_style', action.type == 'account' ? _header.string('account_style', 'icon') : 'outline');
    final Color color = action.color ?? _color(_header.string('${prefix}_color', _header.string('icon_color', '#1F2933')), fallbackColor);
    final Color background = _color(_header.string(backgroundKey, '#FFFFFF'), Colors.transparent);
    final double size = _header.number('${prefix}_size', _header.number('icon_size', 24)).clamp(14, 40).toDouble();
    final double radius = _header.number(radiusKey, 12).clamp(0, 24).toDouble();
    final bool selectedWishlist = action.type == 'wishlist' && action.icon == Icons.favorite_rounded;
    final String variant = _header.string('${action.type}_icon_variant', '');
    final IconData icon = AppConfig.isCmsPreview &&
            _usesApplicationIcon(action.type, variant)
        ? action.icon
        : _iconFor(
            action.type,
            variant,
            style == 'filled' || selectedWishlist,
          );
    final Widget button = IconButton(
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
    if (action.type != 'cart' || !_header.boolean('show_cart_badge', false)) {
      return button;
    }
    return Consumer(
      child: button,
      builder: (BuildContext context, WidgetRef ref, Widget? child) {
        final int count = ref.watch(cartBadgeCountProvider).clamp(0, 99).toInt();
        if (count == 0) return child!;
        final double badgeSize = _header
            .number('cart_badge_size', 18)
            .clamp(12, 30)
            .toDouble();
        final String badgeShape = _header.string(
          'cart_badge_shape',
          'circle',
        );
        final double badgeRadius = badgeShape == 'circle'
            ? badgeSize / 2
            : badgeShape == 'pill'
            ? badgeSize / 2
            : badgeSize * 0.28;
        return Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            child!,
            PositionedDirectional(
              top: -2,
              end: -2,
              child: Container(
                key: const Key('cms-cart-count-badge'),
                constraints: BoxConstraints(
                  minWidth: badgeSize,
                  minHeight: badgeSize,
                ),
                height: badgeSize,
                padding: EdgeInsets.symmetric(
                  horizontal: badgeShape == 'pill' ? 4 : 0,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _color(
                    _header.string('cart_badge_background', '#E94B5F'),
                    Theme.of(context).colorScheme.error,
                  ),
                  borderRadius: BorderRadius.circular(badgeRadius),
                ),
                child: Text(
                  '$count',
                  maxLines: 1,
                  style: TextStyle(
                    color: _color(
                      _header.string('cart_badge_text_color', '#FFFFFF'),
                      Theme.of(context).colorScheme.onError,
                    ),
                    fontSize: (badgeSize * 0.52).clamp(7, 15).toDouble(),
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        );
      },
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

  bool _usesApplicationIcon(String type, String variant) {
    final String normalized = variant.trim();
    return normalized.isEmpty ||
        switch (type) {
          'back' => normalized == 'arrow',
          'search' => normalized == 'rounded',
          'cart' => normalized == 'bag',
          'wishlist' => normalized == 'heart' || normalized == 'rounded',
          'account' => normalized == 'person',
          'orders' => normalized == 'receipt',
          'support' => normalized == 'headset',
          'menu' => normalized == 'menu',
          _ => false,
        };
  }

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
