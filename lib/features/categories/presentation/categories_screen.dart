import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:kidia_store_app/features/catalog/presentation/catalog_copy.dart';
import 'package:kidia_store_app/features/catalog/presentation/models/catalog_category_tree.dart';
import 'package:kidia_store_app/features/catalog/presentation/providers/catalog_category_providers.dart';
import 'package:kidia_store_app/features/search/presentation/catalog_search_launcher.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:kidia_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CatalogCopy copy = CatalogCopy.of(context);
    final AsyncValue<CatalogCategoryTree> tree = ref.watch(
      catalogCategoryTreeProvider,
    );
    final CmsPageLayout layout =
        ref.watch(cmsPageLayoutProvider('category')).value ??
        CmsPageLayout.fallback('category');
    final CatalogCategory? categorySettings =
        tree.asData?.value.roots.isEmpty == false
        ? tree.asData!.value.roots.first.category
        : null;

    return CmsPageScaffold(
      layout: layout,
      backgroundColor: categorySettings == null
          ? null
          : _categoryColor(
              categorySettings.pageBackgroundColor,
              Theme.of(context).colorScheme.surfaceContainerLowest,
            ),
      defaultTitle: copy.categories,
      actions: <CmsPageHeaderAction>[
          CmsPageHeaderAction(key: const Key('categories-search-action'), type: 'search', icon: Icons.search_rounded, tooltip: 'بحث', onPressed: () => showCatalogSearch(context)),
          CmsPageHeaderAction(type: 'cart', icon: Icons.shopping_bag_outlined, tooltip: 'السلة', onPressed: () => context.go('/cart')),
      ],
      body: SafeArea(
        bottom: false,
        child: tree.when(
          loading: _CategoryLoadingList.new,
          error: (Object error, StackTrace stackTrace) => _CategoryStatus(
            icon: Icons.cloud_off_outlined,
            title: copy.connectionError,
            actionLabel: copy.retry,
            onAction: () => ref.invalidate(catalogCategoryTreeProvider),
          ),
          data: (CatalogCategoryTree value) {
            if (value.isEmpty) {
              return _CategoryStatus(
                icon: Icons.category_outlined,
                title: copy.noCategories,
                actionLabel: copy.refresh,
                onAction: () => ref.invalidate(catalogCategoryTreeProvider),
              );
            }

            return _CategoryLayoutView(
              tree: value,
              onRefresh: () => ref
                  .refresh(catalogCategoryTreeProvider.future)
                  .then<void>((CatalogCategoryTree _) {}),
            );
          },
        ),
      ),
    );
  }
}

class _CategoryLayoutView extends StatefulWidget {
  const _CategoryLayoutView({required this.tree, required this.onRefresh});

  final CatalogCategoryTree tree;
  final Future<void> Function() onRefresh;

  @override
  State<_CategoryLayoutView> createState() => _CategoryLayoutViewState();
}

class _CategoryLayoutViewState extends State<_CategoryLayoutView> {
  int _selectedRoot = 0;

  CatalogCategory get _settings => widget.tree.roots.first.category;

  @override
  Widget build(BuildContext context) {
    final String layout = _settings.categoryLayout;
    if (layout == 'sidebar') return _sidebar(context);
    if (layout == 'default') return _defaultList();
    return _grid(layout);
  }

  Widget _defaultList() {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        key: const Key('category-layout-default'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.fromSTEB(
          16,
          14 + _settings.marginTop,
          16,
          24 + _settings.marginBottom,
        ),
        itemCount: widget.tree.roots.length,
        separatorBuilder: (_, _) => SizedBox(height: _settings.cardGap),
        itemBuilder: (BuildContext context, int index) =>
            _CategoryBranch(node: widget.tree.roots[index]),
      ),
    );
  }

  Widget _grid(String layout) {
    final List<CatalogCategoryNode> nodes = _flatten(widget.tree.roots);
    final int columns = layout == 'circular_grid'
        ? 3
        : layout == 'compact_grid'
        ? _settings.gridColumns.clamp(3, 4)
        : _settings.gridColumns.clamp(2, 3);
    final double imageLimit = layout == 'compact_grid'
        ? 62
        : layout == 'circular_grid'
        ? 92
        : 112;
    final double extent = (imageLimit.clamp(32, _settings.imageSize) +
            _settings.imageTextGap +
            (_settings.fontSize * _settings.lineHeight * _settings.textMaxLines) +
            24)
        .clamp(layout == 'compact_grid' ? 150 : 196, 280)
        .toDouble();
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: GridView.builder(
        key: Key('category-layout-$layout'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.fromSTEB(
          16,
          14 + _settings.marginTop,
          16,
          24 + _settings.marginBottom,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: _settings.cardGap,
          crossAxisSpacing: _settings.cardGap,
          mainAxisExtent: extent,
        ),
        itemCount: nodes.length,
        itemBuilder: (BuildContext context, int index) => _CategoryGridTile(
          category: nodes[index].category,
          circular: layout == 'circular_grid',
          compact: layout == 'compact_grid',
        ),
      ),
    );
  }

  Widget _sidebar(BuildContext context) {
    final List<CatalogCategoryNode> roots = widget.tree.roots;
    final int selected = _selectedRoot.clamp(0, roots.length - 1);
    final CatalogCategoryNode root = roots[selected];
    final List<CatalogCategoryNode> detail = root.children.isEmpty
        ? <CatalogCategoryNode>[root]
        : _flatten(root.children);
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: Padding(
        padding: EdgeInsets.only(
          top: _settings.marginTop,
          bottom: _settings.marginBottom,
        ),
        child: Row(
          key: const Key('category-layout-sidebar'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
          SizedBox(
            width: 112,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: roots.length,
              itemBuilder: (BuildContext context, int index) {
                final bool active = index == selected;
                return InkWell(
                  onTap: () => setState(() => _selectedRoot = index),
                  child: Container(
                    key: Key('category-sidebar-root-${roots[index].category.id}'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
                    color: active
                        ? Theme.of(context).colorScheme.secondaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerLowest,
                    child: Text(
                      roots[index].category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(_settings.cardGap),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: _settings.gridColumns.clamp(2, 3),
                mainAxisSpacing: _settings.cardGap,
                crossAxisSpacing: _settings.cardGap,
                mainAxisExtent: 160,
              ),
              itemCount: detail.length,
              itemBuilder: (BuildContext context, int index) =>
                  _CategoryGridTile(category: detail[index].category),
            ),
          ),
          ],
        ),
      ),
    );
  }

  List<CatalogCategoryNode> _flatten(List<CatalogCategoryNode> nodes) {
    return nodes.expand((CatalogCategoryNode node) sync* {
      yield node;
      yield* _flatten(node.children);
    }).toList(growable: false);
  }
}

class _CategoryGridTile extends StatelessWidget {
  const _CategoryGridTile({
    required this.category,
    this.circular = false,
    this.compact = false,
  });

  final CatalogCategory category;
  final bool circular;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double imageLimit = compact ? 62 : circular ? 92 : 112;
    return Material(
      key: Key('category-grid-tile-${category.id}'),
      color: _categoryColor(category.cardBackgroundColor, theme.colorScheme.surface),
      elevation: category.cardStyle == 'elevated'
          ? (category.cardShadowBlur / 4).clamp(1, 10).toDouble()
          : 0,
      shadowColor: _categoryColor(category.cardShadowColor, Colors.black)
          .withValues(alpha: category.cardShadowStrength),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(category.cardRadius),
        side: category.cardStyle == 'outlined'
            ? BorderSide(color: theme.colorScheme.outlineVariant)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCategoryProducts(context, category),
        child: Padding(
          padding: EdgeInsets.all(compact ? 7 : 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _CategoryArtwork(
                category: category,
                maximumSize: imageLimit,
                forceCircle: circular,
              ),
              SizedBox(height: category.imageTextGap),
              Text(
                category.name,
                maxLines: category.textMaxLines,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _categoryColor(category.fontColor, theme.colorScheme.onSurface),
                  fontSize: category.fontSize,
                  fontWeight: _categoryFontWeight(category.fontWeight),
                  height: category.lineHeight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openCategoryProducts(BuildContext context, CatalogCategory category) {
  final String name = Uri.encodeQueryComponent(category.name);
  context.push('/categories/${category.id}?name=$name');
}

class _CategoryBranch extends StatefulWidget {
  const _CategoryBranch({required this.node});

  final CatalogCategoryNode node;

  @override
  State<_CategoryBranch> createState() => _CategoryBranchState();
}

class _CategoryBranchState extends State<_CategoryBranch> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final CatalogCategory category = widget.node.category;
    final bool hasChildren = widget.node.children.isNotEmpty;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final CatalogCopy copy = CatalogCopy.of(context);
    final double responsive = _categoryResponsiveScale(context);
    final Widget tile = Material(
      color: _categoryColor(category.cardBackgroundColor, colors.surface),
      elevation: category.cardStyle == 'elevated'
          ? (category.cardShadowBlur / 4).clamp(1, 10).toDouble()
          : 0,
      shadowColor: _categoryColor(category.cardShadowColor, Colors.black)
          .withValues(alpha: category.cardShadowStrength),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(category.cardRadius),
        side: category.cardStyle == 'outlined'
            ? BorderSide(color: colors.outlineVariant)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: () => _openProducts(context, category),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 7, 8, 7),
              child: Row(
                children: <Widget>[
                  _CategoryArtwork(
                    category: category,
                    maximumSize: 120 * responsive,
                  ),
                  SizedBox(
                    key: Key('category-image-text-gap-${category.id}'),
                    width: category.imageTextGap * responsive,
                  ),
                  Expanded(
                    child: Text(
                      category.name,
                      key: Key('category-title-${category.id}'),
                      maxLines: category.textMaxLines,
                      overflow: TextOverflow.ellipsis,
                      textAlign: _categoryTextAlign(category.textAlign),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: _categoryColor(
                          category.fontColor,
                          colors.onSurface,
                        ),
                        fontSize: category.fontSize * responsive,
                        fontWeight: _categoryFontWeight(category.fontWeight),
                        height: category.lineHeight,
                      ),
                    ),
                  ),
                  if (hasChildren && category.showArrow)
                    IconButton(
                      tooltip: _expanded ? copy.collapse : copy.expand,
                      onPressed: () => setState(() {
                        _expanded = !_expanded;
                      }),
                      icon: AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 180),
                        child: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    )
                  else if (category.showArrow)
                    const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      12,
                      2,
                      12,
                      14,
                    ),
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        const int columns = 3;
                        const double spacing = 10;
                        final double cardWidth =
                            (constraints.maxWidth - spacing * (columns - 1)) /
                            columns;
                        final double maximumImageSize = cardWidth - 10;
                        final double cardHeight = widget.node.children.fold(
                          0,
                          (double height, CatalogCategoryNode node) {
                            final CatalogCategory child = node.category;
                            final double imageHeight = (child.imageSize * responsive)
                                .clamp(32 * responsive, maximumImageSize)
                                .toDouble();
                            final double textHeight =
                                child.fontSize *
                                responsive *
                                child.lineHeight *
                                child.textMaxLines;
                            final double requested =
                                imageHeight +
                                child.imageTextGap * responsive +
                                textHeight +
                                16;
                            return requested > height ? requested : height;
                          },
                        );
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.node.children.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: spacing,
                                crossAxisSpacing: spacing,
                                mainAxisExtent: cardHeight,
                              ),
                          itemBuilder: (BuildContext context, int index) {
                            final CatalogCategory child =
                                widget.node.children[index].category;
                            return _SubcategoryTile(
                              category: child,
                              maximumImageSize: maximumImageSize,
                              onTap: () => _openProducts(context, child),
                            );
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );

    return tile;
  }

  void _openProducts(BuildContext context, CatalogCategory category) {
    final String name = Uri.encodeQueryComponent(category.name);
    context.push('/categories/${category.id}?name=$name');
  }
}

class _SubcategoryTile extends StatelessWidget {
  const _SubcategoryTile({
    required this.category,
    required this.maximumImageSize,
    required this.onTap,
  });

  final CatalogCategory category;
  final double maximumImageSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final double responsive = _categoryResponsiveScale(context);
    return Material(
      color: _categoryColor(category.cardBackgroundColor, colors.surface),
      elevation: category.cardStyle == 'elevated'
          ? (category.cardShadowBlur / 4).clamp(1, 10).toDouble()
          : 0,
      shadowColor: _categoryColor(category.cardShadowColor, Colors.black)
          .withValues(alpha: category.cardShadowStrength),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(category.cardRadius),
        side: category.cardStyle == 'outlined'
            ? BorderSide(color: colors.outlineVariant)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Center(
                child: _CategoryArtwork(
                  category: category,
                  maximumSize: maximumImageSize,
                ),
              ),
            ),
            SizedBox(height: category.imageTextGap * responsive),
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 0, 5, 8),
              child: Text(
                category.name,
                maxLines: category.textMaxLines,
                overflow: TextOverflow.ellipsis,
                textAlign: _categoryTextAlign(category.textAlign),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: _categoryColor(category.fontColor, colors.onSurface),
                  fontSize: category.fontSize * responsive,
                  fontWeight: _categoryFontWeight(category.fontWeight),
                  height: category.lineHeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryArtwork extends StatelessWidget {
  const _CategoryArtwork({
    required this.category,
    required this.maximumSize,
    this.forceCircle = false,
  });

  final CatalogCategory category;
  final double maximumSize;
  final bool forceCircle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double responsive = _categoryResponsiveScale(context);
    final String? imageUrl =
        category.image?.source.toString() ??
        category.image?.thumbnail?.toString();
    final Widget fallback = ColoredBox(
      color: colors.secondaryContainer,
      child: Icon(Icons.category_outlined, color: colors.onSecondaryContainer),
    );
    final double size = (category.imageSize * responsive)
        .clamp(32 * responsive, maximumSize)
        .toDouble();
    final double radius = forceCircle ? size / 2 : switch (category.imageShape) {
      'circle' => size / 2,
      'rounded' => size * category.imageRadius,
      _ => 0,
    };
    final Alignment alignment = switch (category.imagePosition) {
      'top' => Alignment.topCenter,
      'bottom' => Alignment.bottomCenter,
      'left' => Alignment.centerLeft,
      'right' => Alignment.centerRight,
      _ => Alignment.center,
    };
    Widget artwork = imageUrl == null || imageUrl.isEmpty
        ? fallback
        : Transform.scale(
            scale: category.imageScale,
            alignment: alignment,
            child: AppNetworkImage(
              imageUrl: imageUrl,
              fit: category.imageFit == 'cover' ? BoxFit.cover : BoxFit.contain,
              alignment: alignment,
              backgroundColor: _categoryColor(
                category.imageBackgroundColor,
                colors.surface,
              ),
              semanticLabel: category.name,
              errorWidget: fallback,
            ),
          );
    if (category.imageEffect == 'grayscale') {
      artwork = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: artwork,
      );
    }
    return Container(
      key: Key('category-artwork-${category.id}'),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _categoryColor(category.imageBackgroundColor, colors.surface),
        borderRadius: BorderRadius.circular(radius),
        border: category.imageBorderWidth <= 0
            ? null
            : Border.all(
                color: _categoryColor(
                  category.imageBorderColor,
                  colors.outlineVariant,
                ),
                width: category.imageBorderWidth * responsive,
              ),
        boxShadow: category.imageEffect == 'shadow'
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          (radius - category.imageBorderWidth * responsive)
              .clamp(0, radius)
              .toDouble(),
        ),
        child: SizedBox.expand(child: artwork),
      ),
    );
  }
}

Color _categoryColor(String value, Color fallback) {
  final String hex = value.replaceFirst('#', '');
  final int? parsed = int.tryParse(hex, radix: 16);
  return parsed == null || hex.length != 6
      ? fallback
      : Color(0xFF000000 | parsed);
}

double _categoryResponsiveScale(BuildContext context) {
  final double width = MediaQuery.sizeOf(context).width;
  return (width / 390).clamp(0.82, 1.22).toDouble();
}

TextAlign _categoryTextAlign(String value) => switch (value) {
  'center' => TextAlign.center,
  'end' => TextAlign.end,
  _ => TextAlign.start,
};

FontWeight _categoryFontWeight(int value) => switch (value) {
  400 => FontWeight.w400,
  500 => FontWeight.w500,
  600 => FontWeight.w600,
  700 => FontWeight.w700,
  900 => FontWeight.w900,
  _ => FontWeight.w800,
};

class _CategoryLoadingList extends StatelessWidget {
  const _CategoryLoadingList();

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.surfaceContainer;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) => Container(
        height: 82,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(17),
        ),
      ),
    );
  }
}

class _CategoryStatus extends StatelessWidget {
  const _CategoryStatus({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return RefreshIndicator(
          onRefresh: () async => onAction(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, size: 52, color: colors.primary),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.tonalIcon(
                        onPressed: onAction,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(actionLabel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
