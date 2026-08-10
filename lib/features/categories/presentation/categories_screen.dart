import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:mobishop_store_app/features/catalog/data/models/catalog_category_model.dart';
import 'package:mobishop_store_app/features/catalog/presentation/catalog_copy.dart';
import 'package:mobishop_store_app/features/catalog/presentation/models/catalog_category_tree.dart';
import 'package:mobishop_store_app/features/catalog/presentation/providers/catalog_category_providers.dart';
import 'package:mobishop_store_app/features/search/presentation/catalog_search_launcher.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_preview_layout_bridge.dart';
import 'package:mobishop_store_app/shared/widgets/common/app_network_image.dart';

final cmsPreviewCategorySettingsProvider =
    StreamProvider<Map<String, dynamic>?>(
      (Ref ref) => CmsPreviewLayoutBridge.categorySettings,
    );

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CatalogCopy copy = CatalogCopy.of(context);
    final AsyncValue<CatalogCategoryTree> tree = ref.watch(
      catalogCategoryTreeProvider,
    );
    final AsyncValue<CmsPageLayout> layoutState = ref.watch(
      cmsPageLayoutProvider('category'),
    );
    final CmsPageLayout? loadedLayout = layoutState.value;
    if (loadedLayout == null && !layoutState.hasError) {
      return const Scaffold(body: SafeArea(child: _CategoryLoadingList()));
    }
    final CmsPageLayout layout =
        loadedLayout ?? CmsPageLayout.fallback('category');
    final Map<String, dynamic>? previewSettings = ref
        .watch(cmsPreviewCategorySettingsProvider)
        .value;
    final CatalogCategory? categorySettings = previewSettings != null
        ? CatalogCategoryModel.fromJson(<String, dynamic>{
            'id': 1,
            'name': 'Preview',
            'slug': 'preview',
            'presentation': previewSettings,
          })
        : tree.asData?.value.roots.isEmpty == false
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
        CmsPageHeaderAction(
          key: const Key('categories-search-action'),
          type: 'search',
          icon: Icons.search_rounded,
          tooltip: 'بحث',
          onPressed: () => showCatalogSearch(context),
        ),
        CmsPageHeaderAction(
          type: 'cart',
          icon: Icons.shopping_bag_outlined,
          tooltip: 'السلة',
          onPressed: () => context.go('/cart'),
        ),
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
              settings: categorySettings,
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
  const _CategoryLayoutView({
    required this.tree,
    required this.onRefresh,
    this.settings,
  });

  final CatalogCategoryTree tree;
  final Future<void> Function() onRefresh;
  final CatalogCategory? settings;

  @override
  State<_CategoryLayoutView> createState() => _CategoryLayoutViewState();
}

class _CategoryLayoutViewState extends State<_CategoryLayoutView> {
  int? _selectedRoot;
  int _sidebarRootIndex = 0;
  final Set<int> _expandedRootIds = <int>{};

  CatalogCategory get _settings =>
      widget.settings ?? widget.tree.roots.first.category;

  @override
  Widget build(BuildContext context) {
    final String layout = _settings.categoryLayout;
    final CatalogCategoryNode? selectedRoot = _selectedRoot == null
        ? null
        : widget.tree.roots[_selectedRoot!
              .clamp(0, widget.tree.roots.length - 1)
              .toInt()];
    final List<CatalogCategoryNode> visibleNodes = selectedRoot == null
        ? widget.tree.roots
        : selectedRoot.children;
    final Widget content = layout == 'sidebar'
        ? _sidebar(visibleNodes)
        : layout == 'default'
        ? _defaultList(visibleNodes)
        : _grid(layout, visibleNodes);
    return Transform.translate(
      key: const Key('category-section-layout-merge'),
      offset: Offset(0, _settings.marginBottom - _settings.marginTop),
      child: Padding(
        key: const Key('category-section-layout-spacing'),
        padding: EdgeInsets.only(
          top: _settings.spaceUp,
          bottom: _settings.spaceDown,
        ),
        child: ColoredBox(
          color: _categoryColor(
            _settings.elementBackgroundColor,
            Theme.of(context).colorScheme.surface,
          ),
          child: Column(
            children: <Widget>[
              if (selectedRoot != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    key: const Key('category-back-to-roots'),
                    onPressed: () => setState(() => _selectedRoot = null),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(selectedRoot.category.name),
                  ),
                ),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultList(List<CatalogCategoryNode> nodes) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        key: const Key('category-layout-default'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.fromSTEB(16, 14, 16, 24),
        itemCount: nodes.length,
        separatorBuilder: (_, _) => SizedBox(height: _settings.cardGap),
        itemBuilder: (BuildContext context, int index) {
          final CatalogCategoryNode node = nodes[index];
          final bool expanded = _expandedRootIds.contains(node.category.id);
          return Align(child: FractionallySizedBox(
            widthFactor: _settings.cardWidthPercent / 100,
            child: _CategoryBranch(
              node: node,
              expanded: expanded,
              showInlineChildren:
                  _settings.navigationMode == 'expand_inline',
              onTap: () => _openNode(node),
              onExpand: () => _openNode(node),
            ),
          ));
        },
      ),
    );
  }

  Widget _grid(String layout, List<CatalogCategoryNode> nodes) {
    final int columns = layout == 'visual_grid'
        ? 2
        : _settings.gridColumns.clamp(2, 4).toInt();
    final double imageLimit = layout == 'compact_grid'
        ? 54
        : layout == 'circular_grid'
        ? 82
        : 118;
    final double automaticExtent =
        (imageLimit.clamp(32, _settings.imageSize) +
                _settings.imageTextGap +
                (_settings.fontSize *
                    _settings.lineHeight *
                    _settings.textMaxLines) +
                24)
            .clamp(
              layout == 'compact_grid'
                  ? 82
                  : layout == 'circular_grid'
                  ? 142
                  : 196,
              280,
            )
            .toDouble();
    final double extent = _settings.cardHeight > 0
        ? _settings.cardHeight
        : automaticExtent;
    final List<CatalogCategoryNode> expandedNodes =
        _settings.navigationMode == 'expand_inline'
        ? nodes
              .where(
                (CatalogCategoryNode node) =>
                    _expandedRootIds.contains(node.category.id) &&
                    node.children.isNotEmpty,
              )
              .toList(growable: false)
        : const <CatalogCategoryNode>[];
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: CustomScrollView(
        key: Key('category-layout-$layout'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 14, 16, 12),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: _settings.cardGap,
                crossAxisSpacing: _settings.cardGap,
                mainAxisExtent: extent,
              ),
              delegate: SliverChildBuilderDelegate(
                (BuildContext context, int index) => Align(
                  child: FractionallySizedBox(
                    widthFactor: _settings.cardWidthPercent / 100,
                    heightFactor: 1,
                    child: _CategoryGridTile(
                      node: nodes[index],
                      layout: layout,
                      expanded: _expandedRootIds.contains(
                        nodes[index].category.id,
                      ),
                      onTap: () => _openNode(nodes[index]),
                      onExpand: () => _openNode(nodes[index]),
                    ),
                  ),
                ),
                childCount: nodes.length,
              ),
            ),
          ),
          for (final CatalogCategoryNode node in expandedNodes)
            SliverToBoxAdapter(
              child: _InlineSubcategoryPanel(
                key: Key('category-inline-panel-${node.category.id}'),
                node: node,
                gap: _settings.cardGap,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _sidebar(List<CatalogCategoryNode> nodes) {
    if (nodes.isEmpty) {
      return const SizedBox.shrink();
    }
    final int selectedIndex = _sidebarRootIndex
        .clamp(0, nodes.length - 1)
        .toInt();
    final CatalogCategoryNode selected = nodes[selectedIndex];
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            key: const Key('category-layout-sidebar'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(_settings.cardGap),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - (_settings.cardGap * 2))
                    .clamp(0, double.infinity)
                    .toDouble(),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    key: const Key('category-sidebar-rail'),
                    width: 116,
                    child: Column(
                      children: <Widget>[
                        for (
                          int index = 0;
                          index < nodes.length;
                          index++
                        ) ...<Widget>[
                          if (index > 0) const SizedBox(height: 2),
                          _CategorySidebarRootButton(
                            node: nodes[index],
                            selected: index == selectedIndex,
                            onTap: () {
                              if (_settings.navigationMode ==
                                  'expand_inline') {
                                setState(() => _sidebarRootIndex = index);
                              } else {
                                _openNode(nodes[index]);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(width: _settings.cardGap),
                  Expanded(
                    key: const Key('category-sidebar-detail'),
                    child: _CategorySidebarDetail(
                      selected: selected,
                      showChildren:
                          _settings.navigationMode == 'expand_inline',
                      gap: _settings.cardGap,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openNode(CatalogCategoryNode node) {
    if (_settings.navigationMode == 'expand_inline' && node.children.isNotEmpty) {
      setState(() {
        if (!_expandedRootIds.add(node.category.id)) {
          _expandedRootIds.remove(node.category.id);
        }
      });
      return;
    }
    if (_settings.navigationMode != 'separate_page' && _selectedRoot == null && node.children.isNotEmpty) {
      setState(() => _selectedRoot = widget.tree.roots.indexOf(node));
      return;
    }
    _openCategoryProducts(context, node.category);
  }
}

class _CategorySidebarDetail extends StatelessWidget {
  const _CategorySidebarDetail({
    required this.selected,
    required this.showChildren,
    required this.gap,
  });

  final CatalogCategoryNode selected;
  final bool showChildren;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (!showChildren) {
      return const SizedBox(
        height: 180,
        child: Center(child: Icon(Icons.touch_app_outlined, size: 42)),
      );
    }
    if (selected.children.isEmpty) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.category_outlined, size: 42),
              const SizedBox(height: 8),
              Text(selected.category.name),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            _CategoryArtwork(
              category: selected.category,
              maximumSize: 48,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected.category.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double tileWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: <Widget>[
                for (final CatalogCategoryNode node in selected.children)
                  SizedBox(
                    width: tileWidth,
                    height: 150,
                    child: _SubcategoryTile(
                      category: node.category,
                      maximumImageSize: 76,
                      onTap: () =>
                          _openCategoryProducts(context, node.category),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CategoryGridTile extends StatelessWidget {
  const _CategoryGridTile({
    required this.node,
    required this.layout,
    required this.expanded,
    this.onTap,
    this.onExpand,
  });

  final CatalogCategoryNode node;
  final String layout;
  final bool expanded;
  final VoidCallback? onTap;
  final VoidCallback? onExpand;

  @override
  Widget build(BuildContext context) {
    final CatalogCategory category = node.category;
    final bool circular = layout == 'circular_grid';
    final bool compact = layout == 'compact_grid';
    final bool hasChildren = node.children.isNotEmpty;
    final ThemeData theme = Theme.of(context);
    final double imageLimit = compact
        ? 54
        : circular
        ? 82
        : 118;
    final Widget arrow = AnimatedRotation(
      turns: expanded ? 0.5 : 0,
      duration: const Duration(milliseconds: 180),
      child: Icon(
        hasChildren
            ? Icons.keyboard_arrow_down_rounded
            : Icons.chevron_right_rounded,
        size: compact ? 21 : 20,
      ),
    );
    if (compact) {
      return _CategoryCardSurface(
        category: category,
        child: Material(
          key: Key('category-compact-card-${category.id}'),
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap ?? () => _openCategoryProducts(context, category),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 7, 5, 7),
              child: Row(
                children: <Widget>[
                  _CategoryArtwork(
                    category: category,
                    maximumSize: imageLimit,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: _categoryColor(
                          category.fontColor,
                          theme.colorScheme.onSurface,
                        ),
                        fontWeight: _categoryFontWeight(category.fontWeight),
                      ),
                    ),
                  ),
                  if (category.showArrow)
                    IconButton(
                      key: Key('category-expand-${category.id}'),
                      onPressed: hasChildren ? onExpand : onTap,
                      visualDensity: VisualDensity.compact,
                      icon: arrow,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return _CategoryCardSurface(
      category: category,
      forceMinimal: circular,
      child: Material(
        key: Key(
          circular
              ? 'category-circular-card-${category.id}'
              : 'category-visual-card-${category.id}',
        ),
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap ?? () => _openCategoryProducts(context, category),
          child: Padding(
            padding: EdgeInsets.all(compact ? 7 : 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    _CategoryArtwork(
                      category: category,
                      maximumSize: imageLimit,
                      forceCircle: circular,
                    ),
                    if (category.showArrow)
                      PositionedDirectional(
                        top: -7,
                        end: -7,
                        child: Material(
                          color: theme.colorScheme.surface,
                          shape: const CircleBorder(),
                          elevation: circular ? 0 : 1,
                          child: IconButton(
                            key: Key('category-expand-${category.id}'),
                            onPressed: hasChildren ? onExpand : onTap,
                            visualDensity: VisualDensity.compact,
                            iconSize: 19,
                            icon: arrow,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: category.imageTextGap),
                Text(
                  category.name,
                  maxLines: category.textMaxLines,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: _categoryColor(
                      category.fontColor,
                      theme.colorScheme.onSurface,
                    ),
                    fontSize: category.fontSize,
                    fontWeight: _categoryFontWeight(category.fontWeight),
                    height: category.lineHeight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineSubcategoryPanel extends StatelessWidget {
  const _InlineSubcategoryPanel({
    super.key,
    required this.node,
    required this.gap,
  });

  final CatalogCategoryNode node;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(16, 2, 16, gap),
      padding: EdgeInsets.all(gap),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(node.category.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: Text(
              node.category.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              mainAxisExtent: 142,
            ),
            itemCount: node.children.length,
            itemBuilder: (BuildContext context, int index) {
              final CatalogCategory child = node.children[index].category;
              return _SubcategoryTile(
                category: child,
                maximumImageSize: 72,
                onTap: () => _openCategoryProducts(context, child),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CategorySidebarRootButton extends StatelessWidget {
  const _CategorySidebarRootButton({
    required this.node,
    required this.selected,
    required this.onTap,
  });

  final CatalogCategoryNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final CatalogCategory category = node.category;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colors.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('category-sidebar-root-${category.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 9),
          child: Column(
            children: <Widget>[
              _CategoryArtwork(category: category, maximumSize: 52),
              const SizedBox(height: 5),
              Text(
                category.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? colors.onSecondaryContainer : null,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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

class _CategoryBranch extends StatelessWidget {
  const _CategoryBranch({
    required this.node,
    this.onTap,
    this.onExpand,
    this.expanded = false,
    this.showInlineChildren = false,
  });

  final CatalogCategoryNode node;
  final VoidCallback? onTap;
  final VoidCallback? onExpand;
  final bool expanded;
  final bool showInlineChildren;

  @override
  Widget build(BuildContext context) {
    final CatalogCategory category = node.category;
    final bool hasChildren = node.children.isNotEmpty;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final CatalogCopy copy = CatalogCopy.of(context);
    final double responsive = _categoryResponsiveScale(context);
    final Widget tile = _CategoryCardSurface(
      category: category,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            InkWell(
              onTap: onTap ?? () => _openCategoryProducts(context, category),
              child: SizedBox(
                height: category.cardHeight > 0 ? category.cardHeight : null,
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
                            fontWeight: _categoryFontWeight(
                              category.fontWeight,
                            ),
                            height: category.lineHeight,
                          ),
                        ),
                      ),
                      if (hasChildren && category.showArrow)
                        IconButton(
                          key: Key('category-expand-${category.id}'),
                          tooltip: expanded ? copy.collapse : copy.expand,
                          onPressed: onExpand ?? onTap,
                          icon: AnimatedRotation(
                            turns: expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                            ),
                          ),
                        )
                      else if (category.showArrow)
                        const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: !showInlineChildren || !expanded
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        12,
                        2,
                        12,
                        14,
                      ),
                      child: LayoutBuilder(
                        builder:
                            (BuildContext context, BoxConstraints constraints) {
                              const int columns = 3;
                              const double spacing = 10;
                              final double cardWidth =
                                  (constraints.maxWidth -
                                      spacing * (columns - 1)) /
                                  columns;
                              final double maximumImageSize = cardWidth - 10;
                              final double cardHeight = node.children.fold(0, (
                                double height,
                                CatalogCategoryNode node,
                              ) {
                                final CatalogCategory child = node.category;
                                final double imageHeight =
                                    (child.imageSize * responsive)
                                        .clamp(
                                          32 * responsive,
                                          maximumImageSize,
                                        )
                                        .toDouble();
                                final double textHeight =
                                    child.fontSize *
                                    responsive *
                                    child.lineHeight *
                                    child.textMaxLines;
                                final double automaticHeight =
                                    imageHeight +
                                    child.imageTextGap * responsive +
                                    textHeight +
                                    16;
                                final double requested = child.cardHeight > 0
                                    ? child.cardHeight
                                    : automaticHeight;
                                return requested > height ? requested : height;
                              });
                              return GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: node.children.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: spacing,
                                      crossAxisSpacing: spacing,
                                      mainAxisExtent: cardHeight,
                                ),
                                itemBuilder: (BuildContext context, int index) {
                                  final CatalogCategory child =
                                      node.children[index].category;
                                  return Align(
                                    child: FractionallySizedBox(
                                      widthFactor: child.cardWidthPercent / 100,
                                      heightFactor: 1,
                                      child: _SubcategoryTile(
                                        category: child,
                                        maximumImageSize: maximumImageSize,
                                        onTap: () => _openCategoryProducts(
                                          context,
                                          child,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );

    return tile;
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
    return _CategoryCardSurface(
      category: category,
      child: Material(
        color: Colors.transparent,
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
      ),
    );
  }
}

class _CategoryCardSurface extends StatelessWidget {
  const _CategoryCardSurface({
    required this.category,
    required this.child,
    this.forceMinimal = false,
  });

  final CatalogCategory category;
  final Widget child;
  final bool forceMinimal;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(category.cardRadius);
    return Container(
      decoration: BoxDecoration(
        color: forceMinimal || category.cardStyle == 'minimal'
            ? Colors.transparent
            : _categoryColor(category.cardBackgroundColor, colors.surface),
        borderRadius: radius,
        border: !forceMinimal && category.cardStyle == 'outlined'
            ? Border.all(color: colors.outlineVariant)
            : null,
        boxShadow: !forceMinimal && category.cardStyle == 'elevated'
            ? <BoxShadow>[
                BoxShadow(
                  color: _categoryColor(
                    category.cardShadowColor,
                    Colors.black,
                  ).withValues(alpha: category.cardShadowStrength),
                  blurRadius: category.cardShadowBlur,
                  offset: Offset(0, category.cardShadowOffsetY),
                ),
              ]
            : null,
      ),
      child: ClipRRect(borderRadius: radius, child: child),
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
    final double radius = forceCircle
        ? size / 2
        : switch (category.imageShape) {
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
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
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
