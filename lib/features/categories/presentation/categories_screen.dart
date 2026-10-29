import 'package:flutter/material.dart';
import 'category_grid_metrics.dart';
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
    final entryRevision = ref.watch(categoryEntryRevisionProvider);
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
    final savedSettings = layout.settings['category_general'];
    final Map<String, dynamic>? presentationSettings =
        previewSettings ??
        (savedSettings is Map
            ? Map<String, dynamic>.from(savedSettings)
            : null);
    final CatalogCategory? categorySettings = presentationSettings != null
        ? CatalogCategoryModel.fromJson(<String, dynamic>{
            'id': 1,
            'name': 'Preview',
            'slug': 'preview',
            'presentation': presentationSettings,
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
          tooltip: copy.isArabic ? 'بحث' : 'Search',
          onPressed: () => showCatalogSearch(context),
        ),
        CmsPageHeaderAction(
          type: 'cart',
          icon: Icons.shopping_bag_outlined,
          tooltip: copy.isArabic ? 'السلة' : 'Cart',
          onPressed: () => context.push('/cart'),
        ),
      ],
      body: SafeArea(
        bottom: false,
        child: layout.settings['category_element_enabled'] == false
            ? const SizedBox.shrink()
            : tree.when(
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
                      onAction: () =>
                          ref.invalidate(catalogCategoryTreeProvider),
                    );
                  }

                  return _CategoryLayoutView(
                    key: ValueKey(entryRevision),
                    tree:
                        presentationSettings != null && categorySettings != null
                        ? value.withPresentation(categorySettings)
                        : value,
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
    super.key,
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
  final List<int> _categoryPath = <int>[];
  int _sidebarRootIndex = 0;
  int? _tabRootId;
  final Set<int> _expandedRootIds = <int>{};

  CatalogCategory get _settings =>
      widget.settings ?? widget.tree.roots.first.category;

  @override
  Widget build(BuildContext context) {
    final String layout = _settings.categoryLayout;
    CatalogCategoryNode? selectedRoot;
    final tabRoot = widget.tree.roots.firstWhere(
      (node) => node.category.id == _tabRootId,
      orElse: () => widget.tree.roots.first,
    );
    final baseNodes = layout == 'top_tabs'
        ? (tabRoot.children.isEmpty ? [tabRoot] : tabRoot.children)
        : widget.tree.roots;
    var level = baseNodes;
    for (final id in _categoryPath) {
      final matches = level.where((node) => node.category.id == id);
      if (matches.isEmpty) break;
      selectedRoot = matches.first;
      level = selectedRoot.children;
    }
    final selected = selectedRoot;
    final List<CatalogCategoryNode> visibleNodes = selectedRoot == null
        ? baseNodes
        : selectedRoot.children;
    final Widget content = switch (layout) {
      'sidebar' => _sidebar(visibleNodes),
      'top_tabs' => _tabs(tabRoot, visibleNodes),
      'grouped_shelves' => _shelves(visibleNodes),
      'split_rows' || 'text_directory' => _editorialList(visibleNodes),
      'default' || 'image_banner' => _defaultList(visibleNodes),
      _ => _grid(layout, visibleNodes),
    };
    return PopScope<Object?>(
      canPop: _categoryPath.isEmpty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _categoryPath.isNotEmpty) _goBackOneLevel();
      },
      child: Transform.translate(
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
                if (selected != null || _settings.rootViewAllMode == 'visible')
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: SizedBox(
                      height: 48,
                      child: NavigationToolbar(
                        centerMiddle: true,
                        middleSpacing: 8,
                        leading: selected == null
                            ? const SizedBox(width: 96)
                            : SizedBox(
                                width: 96,
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: IconButton(
                                    key: const Key('category-back-to-roots'),
                                    tooltip: MaterialLocalizations.of(
                                      context,
                                    ).backButtonTooltip,
                                    onPressed: _goBackOneLevel,
                                    icon: const BackButtonIcon(),
                                  ),
                                ),
                              ),
                        middle: Text(
                          selected?.category.name ??
                              CatalogCopy.of(context).categories,
                          key: const Key('category-level-title'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        trailing: SizedBox(
                          width: 96,
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: OutlinedButton(
                              key: const Key('category-view-all'),
                              style: _viewAllButtonStyle(
                                context,
                                _settings.viewAllStyle,
                              ),
                              onPressed: selected == null
                                  ? () => context.push('/products')
                                  : () => _openCategoryProducts(
                                      context,
                                      selected.category,
                                    ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  CatalogCopy.of(context).isArabic
                                      ? 'عرض الكل'
                                      : 'View all',
                                  maxLines: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goBackOneLevel() {
    setState(() {
      _categoryPath.removeLast();
      _sidebarRootIndex = 0;
    });
  }

  Widget _defaultList(List<CatalogCategoryNode> nodes) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        key: Key('category-layout-${_settings.categoryLayout}'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.fromSTEB(16, 14, 16, 24),
        itemCount: nodes.length,
        separatorBuilder: (_, _) => SizedBox(height: _settings.cardGap),
        itemBuilder: (BuildContext context, int index) {
          final CatalogCategoryNode node = nodes[index];
          final bool expanded = _expandedRootIds.contains(node.category.id);
          return Align(
            child: FractionallySizedBox(
              widthFactor: _settings.cardWidthPercent / 100,
              child: _settings.categoryLayout == 'image_banner'
                  ? Column(
                      children: [
                        _CategoryBanner(
                          node: node,
                          expanded: expanded,
                          onTap: () => _openNode(node),
                        ),
                        if (expanded &&
                            _settings.navigationMode == 'expand_inline')
                          _InlineSubcategoryPanel(
                            key: Key(
                              'category-inline-panel-${node.category.id}',
                            ),
                            node: node,
                            gap: _settings.cardGap,
                          ),
                      ],
                    )
                  : _CategoryBranch(
                      node: node,
                      expanded: expanded,
                      showInlineChildren:
                          _settings.navigationMode == 'expand_inline',
                      onTap: () => _openNode(node),
                      onExpand: () => _openNode(node),
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _grid(String layout, List<CatalogCategoryNode> nodes) {
    final int columns = _settings.gridColumns.clamp(2, 4).toInt();
    final double extent = categoryGridExtent(_settings, layout);
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
                mainAxisExtent:
                    layout == 'visual_grid' && _settings.cardHeight <= 0
                    ? null
                    : extent,
                childAspectRatio: 1,
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
                              if (_settings.navigationMode == 'expand_inline' &&
                                  nodes[index].children.isNotEmpty) {
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
                      showChildren: _settings.navigationMode == 'expand_inline',
                      gap: _settings.cardGap,
                      onOpen: () => _openNode(selected),
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

  Widget _tabs(CatalogCategoryNode selected, List<CatalogCategoryNode> nodes) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('category-layout-top_tabs'),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              for (final root in widget.tree.roots)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ChoiceChip(
                    key: Key('category-tab-${root.category.id}'),
                    label: Text(root.category.name),
                    selected: root.category.id == selected.category.id,
                    showCheckmark: false,
                    onSelected: (_) => setState(() {
                      _tabRootId = root.category.id;
                      _categoryPath.clear();
                      _expandedRootIds.clear();
                    }),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selected.category.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () =>
                    _openCategoryProducts(context, selected.category),
                child: Text(
                  CatalogCopy.of(context).isArabic ? 'عرض الكل' : 'View all',
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _grid('visual_grid', nodes)),
      ],
    );
  }

  Widget _editorialList(List<CatalogCategoryNode> nodes) {
    final split = _settings.categoryLayout == 'split_rows';
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        key: Key('category-layout-${_settings.categoryLayout}'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        itemCount: nodes.length,
        separatorBuilder: (_, _) => split
            ? SizedBox(height: _settings.cardGap)
            : Divider(
                height: 1,
                color: Theme.of(context).dividerColor.withValues(alpha: .22),
              ),
        itemBuilder: (context, index) {
          final node = nodes[index];
          final expanded = _expandedRootIds.contains(node.category.id);
          return Column(
            children: [
              _CategoryEditorialRow(
                node: node,
                split: split,
                expanded: expanded,
                onTap: () => _openNode(node),
              ),
              if (expanded && _settings.navigationMode == 'expand_inline')
                _InlineSubcategoryPanel(
                  key: Key('category-inline-panel-${node.category.id}'),
                  node: node,
                  gap: _settings.cardGap,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _shelves(List<CatalogCategoryNode> nodes) {
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.separated(
        key: const Key('category-layout-grouped_shelves'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: nodes.length,
        separatorBuilder: (_, _) => const SizedBox(height: 22),
        itemBuilder: (context, index) {
          final node = nodes[index];
          if (node.children.isEmpty) {
            return _CategoryEditorialRow(
              node: node,
              split: true,
              expanded: false,
              onTap: () => _openNode(node),
            );
          }
          final height =
              (148 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2))
                  .toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      node.category.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        _openCategoryProducts(context, node.category),
                    child: Text(
                      CatalogCopy.of(context).isArabic
                          ? 'عرض الكل'
                          : 'View all',
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: height,
                child: ListView.separated(
                  key: Key('category-shelf-${node.category.id}'),
                  scrollDirection: Axis.horizontal,
                  itemCount: node.children.length,
                  separatorBuilder: (_, _) =>
                      SizedBox(width: _settings.cardGap),
                  itemBuilder: (context, childIndex) {
                    final child = node.children[childIndex];
                    return SizedBox(
                      width: 124,
                      child: _CategoryGridTile(
                        node: child,
                        layout: 'visual_grid',
                        expanded: _expandedRootIds.contains(child.category.id),
                        onTap: () => _openNode(child, ancestor: node),
                        onExpand: () => _openNode(child, ancestor: node),
                      ),
                    );
                  },
                ),
              ),
              if (_settings.navigationMode == 'expand_inline')
                for (final child in node.children)
                  if (_expandedRootIds.contains(child.category.id) &&
                      child.children.isNotEmpty)
                    _InlineSubcategoryPanel(
                      key: Key('category-inline-panel-${child.category.id}'),
                      node: child,
                      gap: _settings.cardGap,
                    ),
            ],
          );
        },
      ),
    );
  }

  void _openNode(CatalogCategoryNode node, {CatalogCategoryNode? ancestor}) {
    if (_settings.navigationMode == 'products_with_children' &&
        (_categoryPath.isNotEmpty ||
            ancestor != null ||
            _settings.categoryLayout == 'top_tabs')) {
      _openCategoryProducts(context, node.category);
      return;
    }
    if (_settings.navigationMode == 'expand_inline' &&
        node.children.isNotEmpty) {
      setState(() {
        if (!_expandedRootIds.add(node.category.id)) {
          _expandedRootIds.remove(node.category.id);
        }
      });
      return;
    }
    if (node.children.isNotEmpty) {
      setState(() {
        if (ancestor != null) _categoryPath.add(ancestor.category.id);
        _categoryPath.add(node.category.id);
        _sidebarRootIndex = 0;
        _expandedRootIds.clear();
      });
      return;
    }
    _openCategoryProducts(context, node.category);
  }
}

/// The same category artwork and surfaces, compacted above the product filters.
class CategoryProductsRail extends ConsumerWidget {
  const CategoryProductsRail({
    required this.categoryId,
    required this.onSelected,
    this.selectedCategoryId,
    super.key,
  });
  final int categoryId;
  final int? selectedCategoryId;
  final ValueChanged<CatalogCategory> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tree = ref.watch(catalogCategoryTreeProvider).value;
    final layout = ref.watch(cmsPageLayoutProvider('category')).value;
    final raw =
        ref.watch(cmsPreviewCategorySettingsProvider).value ??
        layout?.settings['category_general'];
    if (tree == null || raw is! Map) return const SizedBox.shrink();
    final settings = CatalogCategoryModel.fromJson({
      'id': 1,
      'name': 'Categories',
      'slug': 'categories',
      'presentation': Map<String, dynamic>.from(raw),
    });
    if (settings.navigationMode != 'products_with_children') {
      return const SizedBox.shrink();
    }
    CatalogCategoryNode? find(List<CatalogCategoryNode> nodes) {
      for (final node in nodes) {
        if (node.category.id == categoryId) return node;
        final match = find(node.children);
        if (match != null) return match;
      }
      return null;
    }

    final children =
        find(tree.roots)?.children ?? const <CatalogCategoryNode>[];
    if (children.isEmpty) return const SizedBox.shrink();
    return CategoryProductsCards(
      categories: children
          .map((node) => node.category.withPresentation(settings))
          .toList(),
      selectedCategoryId: selectedCategoryId,
      onSelected: onSelected,
    );
  }
}

class CategoryProductsCards extends StatelessWidget {
  const CategoryProductsCards({
    required this.categories,
    required this.onSelected,
    this.selectedCategoryId,
    super.key,
  });
  final List<CatalogCategory> categories;
  final int? selectedCategoryId;
  final ValueChanged<CatalogCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const Key('category-products-rail'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = categories.length <= 3 ? 3 : 4;
          const gap = 10.0;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          final textHeight = MediaQuery.textScalerOf(context).scale(13) * 2.6;
          return SizedBox(
            height: width + textHeight + 14,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: gap),
              itemBuilder: (context, index) {
                final category = categories[index];
                return SizedBox(
                  key: Key('category-products-card-${category.id}'),
                  width: width,
                  child: Semantics(
                    selected: category.id == selectedCategoryId,
                    child: _CategoryCardSurface(
                      category: category,
                      selected: category.id == selectedCategoryId,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => onSelected(category),
                          child: Column(
                            children: [
                              SizedBox(
                                height: width,
                                child: Center(
                                  child: _CategoryArtwork(
                                    category: category,
                                    maximumSize: width,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: _CategoryNameHighlight(
                                  category: category,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                  child: Center(
                                    child: Text(
                                      category.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.2,
                                        color: _categoryColor(
                                          category.fontColor,
                                          Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                        fontWeight: _categoryFontWeight(
                                          category.fontWeight,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CategoryEditorialRow extends StatelessWidget {
  const _CategoryEditorialRow({
    required this.node,
    required this.split,
    required this.expanded,
    required this.onTap,
  });
  final CatalogCategoryNode node;
  final bool split;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = node.category;
    final theme = Theme.of(context);
    final title = _CategoryNameHighlight(
      category: category,
      child: Text(
        category.name,
        maxLines: category.textMaxLines,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium?.copyWith(
          fontSize: category.fontSize,
          fontWeight: _categoryFontWeight(category.fontWeight),
          color: _categoryColor(
            category.fontColor,
            theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
    final arrow = category.showArrow
        ? Icon(
            node.children.isEmpty
                ? Icons.chevron_right_rounded
                : expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 20,
          )
        : const SizedBox.shrink();
    return Material(
      key: Key('category-${split ? 'split' : 'directory'}-card-${category.id}'),
      color: split
          ? _categoryColor(
              category.cardBackgroundColor,
              theme.colorScheme.surfaceContainerLow,
            )
          : Colors.transparent,
      borderRadius: BorderRadius.circular(split ? category.cardRadius : 0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: split
            ? SizedBox(
                height: category.cardHeight > 0 ? category.cardHeight : 128,
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(child: title),
                            const SizedBox(height: 8),
                            arrow,
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: SizedBox.expand(
                        child: category.image != null
                            ? AppNetworkImage(
                                imageUrl: category.image!.source.toString(),
                                fit: category.imageFit == 'cover'
                                    ? BoxFit.cover
                                    : BoxFit.contain,
                              )
                            : ColoredBox(
                                color: theme.colorScheme.surfaceContainerLow,
                                child: Icon(
                                  Icons.category_outlined,
                                  size: 42,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 12),
                    arrow,
                  ],
                ),
              ),
      ),
    );
  }
}

class _CategoryBanner extends StatelessWidget {
  const _CategoryBanner({
    required this.node,
    required this.expanded,
    required this.onTap,
  });
  final CatalogCategoryNode node;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final category = node.category;
    return Material(
      key: Key('category-banner-card-${category.id}'),
      borderRadius: BorderRadius.circular(category.cardRadius),
      clipBehavior: Clip.antiAlias,
      color: const Color(0xff426f64),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: category.cardHeight > 0 ? category.cardHeight : 164,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(
                imageUrl: category.image?.source.toString() ?? '',
                fit: BoxFit.cover,
                semanticLabel: category.name,
                errorWidget: const Center(
                  child: Icon(
                    Icons.category_outlined,
                    color: Colors.white54,
                    size: 56,
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x10000000), Color(0xcc000000)],
                  ),
                ),
              ),
              PositionedDirectional(
                start: 18,
                end: 16,
                bottom: 18,
                child: Row(
                  children: [
                    Expanded(
                      child: _CategoryNameHighlight(
                        category: category,
                        child: Text(
                          category.name,
                          maxLines: category.textMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: category.nameHighlightEnabled
                                ? _categoryColor(
                                    category.fontColor,
                                    Colors.black,
                                  )
                                : Colors.white,
                            fontSize: category.fontSize,
                            fontWeight: _categoryFontWeight(
                              category.fontWeight,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (category.showArrow)
                      IconButton(
                        key: Key('category-expand-${category.id}'),
                        onPressed: onTap,
                        icon: Icon(
                          expanded
                              ? Icons.keyboard_arrow_up
                              : Icons.arrow_forward_rounded,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySidebarDetail extends StatelessWidget {
  const _CategorySidebarDetail({
    required this.selected,
    required this.showChildren,
    required this.gap,
    required this.onOpen,
  });

  final CatalogCategoryNode selected;
  final bool showChildren;
  final double gap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    if (!showChildren || selected.children.isEmpty) {
      return _CategoryBanner(node: selected, expanded: false, onTap: onOpen);
    }
    return _InlineSubcategoryPanel(
      key: ValueKey(selected.category.id),
      node: selected,
      gap: gap,
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
    if (layout == 'visual_grid') {
      return _CategoryCardSurface(
        category: category,
        child: Material(
          key: Key('category-visual-card-${category.id}'),
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap ?? () => _openCategoryProducts(context, category),
            child: Column(
              children: <Widget>[
                Expanded(
                  child: ClipRect(
                    child: Transform.scale(
                      key: Key('category-visual-image-${category.id}'),
                      scale: category.imageScale,
                      alignment: _categoryImageAlignment(
                        category.imagePosition,
                      ),
                      child: SizedBox.expand(
                        child: category.image != null
                            ? AppNetworkImage(
                                imageUrl: category.image!.source.toString(),
                                fit: category.imageFit == 'contain'
                                    ? BoxFit.contain
                                    : BoxFit.cover,
                                alignment: _categoryImageAlignment(
                                  category.imagePosition,
                                ),
                              )
                            : ColoredBox(
                                color: theme.colorScheme.surfaceContainerLow,
                                child: Icon(
                                  Icons.category_outlined,
                                  size: 38,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                _CategoryNameHighlight(
                  category: category,
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      10,
                      category.nameVerticalPadding,
                      6,
                      category.nameVerticalPadding,
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: category.textAlign == 'center'
                                ? Alignment.center
                                : category.textAlign == 'end'
                                ? AlignmentDirectional.centerEnd
                                : AlignmentDirectional.centerStart,
                            child: Text(
                              category.name,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              textAlign: _categoryTextAlign(category.textAlign),
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: _categoryColor(
                                  category.fontColor,
                                  theme.colorScheme.onSurface,
                                ),
                                fontSize: category.fontSize,
                                fontWeight: _categoryFontWeight(
                                  category.fontWeight,
                                ),
                                height: category.lineHeight,
                              ),
                            ),
                          ),
                        ),
                        if (category.showArrow)
                          IconButton(
                            key: Key('category-expand-${category.id}'),
                            onPressed: hasChildren ? onExpand : onTap,
                            visualDensity: VisualDensity.compact,
                            constraints: const BoxConstraints.tightFor(
                              width: 30,
                              height: 30,
                            ),
                            padding: EdgeInsets.zero,
                            icon: arrow,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
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
                  _CategoryArtwork(category: category, maximumSize: imageLimit),
                  SizedBox(width: category.imageTextGap),
                  Expanded(
                    child: _CategoryNameHighlight(
                      category: category,
                      child: Text(
                        category.name,
                        maxLines: category.textMaxLines,
                        overflow: TextOverflow.ellipsis,
                        textAlign: _categoryTextAlign(category.textAlign),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: _categoryColor(
                            category.fontColor,
                            theme.colorScheme.onSurface,
                          ),
                          fontWeight: _categoryFontWeight(category.fontWeight),
                          fontSize: category.fontSize,
                          height: category.lineHeight,
                        ),
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
                SizedBox(
                  width: double.infinity,
                  child: _CategoryNameHighlight(
                    category: category,
                    child: Text(
                      category.name,
                      maxLines: category.textMaxLines,
                      overflow: TextOverflow.ellipsis,
                      textAlign: _categoryTextAlign(category.textAlign),
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

class _InlineSubcategoryPanel extends StatefulWidget {
  const _InlineSubcategoryPanel({
    super.key,
    required this.node,
    required this.gap,
  });

  final CatalogCategoryNode node;
  final double gap;

  @override
  State<_InlineSubcategoryPanel> createState() =>
      _InlineSubcategoryPanelState();
}

class _InlineSubcategoryPanelState extends State<_InlineSubcategoryPanel> {
  int? expandedId;
  CatalogCategoryNode get node => widget.node;
  double get gap => widget.gap;

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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    node.category.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      _openCategoryProducts(context, node.category),
                  child: Text(
                    CatalogCopy.of(context).isArabic ? 'عرض الكل' : 'View all',
                  ),
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: (constraints.maxWidth / 100).floor().clamp(
                  1,
                  3,
                ),
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                mainAxisExtent: node.children
                    .map((child) {
                      final category = child.category;
                      return (72 +
                                  category.imageTextGap +
                                  category.fontSize *
                                      category.lineHeight *
                                      category.textMaxLines) *
                              _categoryResponsiveScale(context) +
                          20;
                    })
                    .fold<double>(
                      142,
                      (height, value) => value > height ? value : height,
                    ),
              ),
              itemCount: node.children.length,
              itemBuilder: (BuildContext context, int index) {
                final CatalogCategory child = node.children[index].category;
                return _SubcategoryTile(
                  category: child,
                  maximumImageSize: 72,
                  onTap: () {
                    if (node.children[index].children.isEmpty) {
                      _openCategoryProducts(context, child);
                    } else {
                      setState(
                        () => expandedId = expandedId == child.id
                            ? null
                            : child.id,
                      );
                    }
                  },
                );
              },
            ),
          ),
          for (final child in node.children)
            if (child.category.id == expandedId)
              _InlineSubcategoryPanel(
                key: ValueKey(child.category.id),
                node: child,
                gap: gap,
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
              _CategoryArtwork(category: category, maximumSize: 102),
              SizedBox(height: category.imageTextGap),
              SizedBox(
                width: double.infinity,
                child: _CategoryNameHighlight(
                  category: category,
                  child: Text(
                    category.name,
                    maxLines: category.textMaxLines,
                    overflow: TextOverflow.ellipsis,
                    textAlign: _categoryTextAlign(category.textAlign),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: _categoryColor(
                        category.fontColor,
                        selected
                            ? colors.onSecondaryContainer
                            : colors.onSurface,
                      ),
                      fontWeight: _categoryFontWeight(category.fontWeight),
                      fontSize: category.fontSize,
                      height: category.lineHeight,
                    ),
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

void _openCategoryProducts(BuildContext context, CatalogCategory category) {
  final String name = Uri.encodeQueryComponent(category.name);
  context.push('/categories/${category.id}?name=$name');
}

ButtonStyle _viewAllButtonStyle(BuildContext context, String style) {
  final colors = Theme.of(context).colorScheme;
  final soft = style == 'soft';
  return OutlinedButton.styleFrom(
    minimumSize: const Size(64, 32),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    foregroundColor: soft ? colors.onSurface : null,
    backgroundColor: soft
        ? Color.alphaBlend(
            colors.primary.withValues(alpha: .10),
            colors.surface,
          )
        : null,
    textStyle: TextStyle(
      fontSize: soft ? 13 : 12,
      fontWeight: soft ? FontWeight.w700 : FontWeight.w600,
    ),
    side: BorderSide(
      color: colors.primary.withValues(alpha: soft ? .55 : .28),
      width: soft ? 1 : .7,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
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
                        child: _CategoryNameHighlight(
                          category: category,
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
                  : _InlineSubcategoryPanel(node: node, gap: category.cardGap),
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
              _CategoryNameHighlight(
                category: category,
                padding: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(5, 0, 5, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      category.name,
                      maxLines: category.textMaxLines,
                      overflow: TextOverflow.ellipsis,
                      textAlign: _categoryTextAlign(category.textAlign),
                      style: theme.textTheme.labelMedium?.copyWith(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryNameHighlight extends StatelessWidget {
  const _CategoryNameHighlight({
    required this.category,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  });
  final CatalogCategory category;
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    if (!category.nameHighlightEnabled) return child;
    return ColoredBox(
      key: Key('category-name-highlight-${category.id}'),
      color: _categoryColor(
        category.nameHighlightColor,
        const Color(0xffeff8f5),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _CategoryCardSurface extends StatelessWidget {
  const _CategoryCardSurface({
    required this.category,
    required this.child,
    this.forceMinimal = false,
    this.selected = false,
  });

  final CatalogCategory category;
  final Widget child;
  final bool forceMinimal;
  final bool selected;

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
      foregroundDecoration: selected
          ? BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: radius,
              border: Border.all(
                color: colors.primary.withValues(alpha: 0.55),
                width: 1.25,
              ),
            )
          : null,
      child: ClipRRect(borderRadius: radius, child: child),
    );
  }
}

Alignment _categoryImageAlignment(String position) => switch (position) {
  'top' => Alignment.topCenter,
  'bottom' => Alignment.bottomCenter,
  'left' => Alignment.centerLeft,
  'right' => Alignment.centerRight,
  _ => Alignment.center,
};

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
    final Alignment alignment = _categoryImageAlignment(category.imagePosition);
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
