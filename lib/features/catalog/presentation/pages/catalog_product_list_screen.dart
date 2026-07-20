import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/brands/domain/entities/store_brand.dart';
import 'package:kidia_store_app/features/brands/presentation/providers/brands_providers.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:kidia_store_app/features/catalog/presentation/catalog_copy.dart';
import 'package:kidia_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';
import 'package:kidia_store_app/features/catalog/presentation/providers/catalog_product_list_provider.dart';
import 'package:kidia_store_app/features/catalog/presentation/widgets/catalog_product_card.dart';
import 'package:kidia_store_app/features/catalog/presentation/widgets/catalog_product_filter_sheet.dart';
import 'package:kidia_store_app/features/catalog/presentation/widgets/catalog_size_sheet.dart';
import 'package:kidia_store_app/features/catalog/presentation/widgets/catalog_sort_sheet.dart';
import 'package:kidia_store_app/features/search/presentation/catalog_search_launcher.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';

class CatalogProductListScreen extends StatelessWidget {
  const CatalogProductListScreen({
    required this.request,
    super.key,
    this.showSearchField = false,
  });

  final CatalogProductListRequest request;
  final bool showSearchField;

  @override
  Widget build(BuildContext context) {
    final CatalogCopy copy = CatalogCopy.of(context);
    final String title = request.title.trim().isEmpty ? copy.products : request.title;
    return CmsPageLayoutLoader(
      page: 'catalog',
      builder: (BuildContext context, CmsPageLayout layout) {
        final CatalogProductListRequest effectiveRequest = CatalogProductListRequest(
          title: request.title,
          search: request.search,
          categoryId: request.categoryId,
          brandId: request.brandId,
          collection: request.collection,
          searchOnly: request.searchOnly,
          pageSize: layout.element('product_grid').number('products_per_page', request.pageSize.toDouble()).round(),
        );
        return CmsPageScaffold(
          layout: layout,
          defaultTitle: title,
          actions: <CmsPageHeaderAction>[
            CmsPageHeaderAction(
              type: 'search',
              icon: Icons.search_rounded,
              tooltip: copy.search,
              onPressed: () => showCatalogSearch(context, initialQuery: request.search),
            ),
            CmsPageHeaderAction(
              type: 'cart',
              icon: Icons.shopping_bag_outlined,
              tooltip: 'Cart',
              onPressed: () => context.push('/cart'),
            ),
          ],
          body: CatalogProductListView(
            request: effectiveRequest,
            showSearchField: showSearchField,
            pageLayout: layout,
          ),
        );
      },
    );
  }
}

class CatalogProductListView extends ConsumerStatefulWidget {
  const CatalogProductListView({
    required this.request,
    super.key,
    this.showSearchField = true,
    this.pageLayout,
  });

  final CatalogProductListRequest request;
  final bool showSearchField;
  final CmsPageLayout? pageLayout;

  @override
  ConsumerState<CatalogProductListView> createState() =>
      _CatalogProductListViewState();
}

class _CatalogProductListViewState
    extends ConsumerState<CatalogProductListView> {
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _searchController = TextEditingController(text: widget.request.search);
  }

  @override
  void didUpdateWidget(covariant CatalogProductListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.search != widget.request.search) {
      _searchController.value = TextEditingValue(
        text: widget.request.search,
        selection: TextSelection.collapsed(
          offset: widget.request.search.length,
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final ScrollPosition position = _scrollController.position;
    final CmsPageComponent grid = (widget.pageLayout ?? CmsPageLayout.fallback('catalog')).element('product_grid');
    if (grid.string('pagination_mode', 'load_more') == 'automatic' && position.extentAfter < 520) {
      ref.read(catalogProductListControllerProvider(widget.request)).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final CatalogProductListController controller = ref.watch(
      catalogProductListControllerProvider(widget.request),
    );

    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        return _ProductListContent(
          controller: controller,
          scrollController: _scrollController,
          searchController: _searchController,
          showSearchField: widget.showSearchField,
          pageLayout: widget.pageLayout ?? CmsPageLayout.fallback('catalog'),
        );
      },
    );
  }
}

class _ProductListContent extends StatelessWidget {
  const _ProductListContent({
    required this.controller,
    required this.scrollController,
    required this.searchController,
    required this.showSearchField,
    required this.pageLayout,
  });

  final CatalogProductListController controller;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final bool showSearchField;
  final CmsPageLayout pageLayout;

  @override
  Widget build(BuildContext context) {
    final CatalogProductListState state = controller.state;
    final CatalogCopy copy = CatalogCopy.of(context);

    return RefreshIndicator(
      onRefresh: () => controller.loadInitial(refresh: true),
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: <Widget>[
          if (showSearchField)
            SliverToBoxAdapter(
              child: _SearchField(
                controller: searchController,
                hint: copy.searchHint,
                onSubmitted: controller.submitSearch,
                onClear: () {
                  searchController.clear();
                  controller.submitSearch('');
                },
              ),
            ),
          if (!controller.isAwaitingSearch && pageLayout.element('filter_bar').enabled)
            SliverPersistentHeader(
              pinned: pageLayout.element('filter_bar').boolean('sticky', true),
              delegate: _CatalogToolbarHeaderDelegate(
                extent: _elementExtent(
                  pageLayout.element('filter_bar'),
                  pageLayout.element('filter_bar').number('block_height', 56).clamp(48, 100),
                ),
                child: CmsElementFrame(
                  component: pageLayout.element('filter_bar'),
                  child: _CatalogToolbar(
                    state: state,
                    controller: controller,
                    settings: pageLayout.element('filter_bar'),
                  ),
                ),
              ),
            ),
          if (controller.isAwaitingSearch)
            _StatusFill(
              icon: Icons.manage_search_rounded,
              title: copy.searchPrompt,
            )
          else if (state.isInitialLoading && state.items.isEmpty)
            const _CatalogLoadingGrid()
          else if (state.error != null && state.items.isEmpty)
            _StatusFill(
              icon: Icons.cloud_off_outlined,
              title: _friendlyError(copy, state.error!),
              actionLabel: copy.retry,
              onAction: controller.loadInitial,
            )
          else if (state.items.isEmpty)
            _StatusFill(
              icon: Icons.inventory_2_outlined,
              title: copy.noProducts,
              actionLabel: state.filters.isEmpty ? null : copy.reset,
              onAction: state.filters.isEmpty
                  ? null
                  : () =>
                        controller.applyFilters(const CatalogProductFilters()),
            )
          else ...<Widget>[
            if (pageLayout.element('product_grid').enabled)
              _CatalogProductGrid(
                items: state.items,
                settings: pageLayout.element('product_grid'),
              ),
            if (pageLayout.element('product_grid').string('pagination_mode', 'load_more') != 'none')
              SliverToBoxAdapter(
                child: _PaginationFooter(
                  state: state,
                  onRetry: controller.loadMore,
                  onLoadMore: controller.loadMore,
                  settings: pageLayout.element('product_grid'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static double _elementExtent(CmsPageComponent component, double content) {
    return content +
        (component.number('padding_vertical', 0).clamp(0, 40) * 2);
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 4),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        autocorrect: false,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 26.4),
          suffixIcon: ListenableBuilder(
            listenable: controller,
            builder: (BuildContext context, Widget? child) => controller.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        onSubmitted: (String value) {
          FocusScope.of(context).unfocus();
          onSubmitted(value);
        },
      ),
    );
  }
}

class _CatalogToolbar extends ConsumerWidget {
  const _CatalogToolbar({required this.state, required this.controller, required this.settings});

  final CatalogProductListState state;
  final CatalogProductListController controller;
  final CmsPageComponent settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CatalogCopy copy = CatalogCopy.of(context);
    final List<StoreBrand> brands = ref
        .watch(catalogFilterBrandsProvider)
        .when(
          data: (List<StoreBrand> value) => value,
          loading: () => const <StoreBrand>[],
          error: (Object error, StackTrace stackTrace) => const <StoreBrand>[],
        );
    final double gap = settings.number('button_gap', 8).clamp(0, 24).toDouble();
    final double iconSize = settings.number('icon_size', 22).clamp(14, 36).toDouble();
    final double widthFactor = settings.number('block_width', 100).clamp(40, 100).toDouble() / 100;
    final Color iconColor = _cmsColor(settings.string('icon_color', '#1F2933'), Theme.of(context).colorScheme.onSurface);
    final Color borderColor = _cmsColor(settings.string('border_color', '#DDE3E8'), Theme.of(context).dividerColor);
    final Color backgroundColor = _cmsColor(settings.string('background_color', '#FFFFFF'), Theme.of(context).colorScheme.surface);
    final double buttonRadius = settings.number('button_radius', 12).clamp(0, 28).toDouble();
    return ColoredBox(color: backgroundColor, child: FractionallySizedBox(
      widthFactor: widthFactor,
      child: Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
      child: Row(
        children: <Widget>[
          if (settings.boolean('show_filter', true))
          Expanded(
            child: Badge(
              isLabelVisible: state.filters.generalActiveCount > 0,
              label: Text('${state.filters.generalActiveCount}'),
              child: _ToolbarButton(
                key: const Key('catalog-filter-button'),
                icon: Icons.tune_rounded,
				iconOffsetY: settings.number('filter_icon_offset_y', -2).clamp(-8, 8),
                iconSize: iconSize,
                iconColor: iconColor,
                borderColor: borderColor,
                radius: buttonRadius,
                label: copy.filter,
                onPressed: () async {
                  final int minorUnit = state.items.isEmpty
                      ? 2
                      : state.items.first.prices.currencyMinorUnit;
                  final CatalogProductFilters? filters =
                      await CatalogProductFilterSheet.show(
                        context,
                        initialFilters: state.filters,
                        currencyMinorUnit: minorUnit,
                        minimumAvailableMinor:
                            state.filterData?.minimumPriceMinor ?? '',
                        maximumAvailableMinor:
                            state.filterData?.maximumPriceMinor ?? '',
                        brands: brands,
                        showPrice: settings.boolean('filter_price', true),
                        showSale: settings.boolean('filter_sale', true),
                        showBrand: settings.boolean('filter_brand', true),
                      );
                  if (filters != null) {
                    await controller.applyFilters(filters);
                  }
                },
              ),
            ),
          ),
          if (settings.boolean('show_filter', true) && settings.boolean('filter_size', true)) SizedBox(width: gap),
          if (settings.boolean('filter_size', true))
          Expanded(
            child: Badge(
              isLabelVisible: state.filters.hasSize,
              label: const Icon(Icons.check_rounded, size: 12),
              child: _ToolbarButton(
                key: const Key('catalog-size-button'),
                icon: Icons.straighten_rounded,
                iconSize: iconSize,
                iconColor: iconColor,
                borderColor: borderColor,
                radius: buttonRadius,
                label: copy.size,
                onPressed: () async {
                  final CatalogSizeSelection? selection =
                      await CatalogSizeSheet.show(
                        context,
                        options: state.availableSizes,
                        selectedFilters: state.filters,
                      );
                  if (selection != null) {
                    await controller.applySize(selection.option);
                  }
                },
              ),
            ),
          ),
          if (settings.boolean('filter_size', true) && settings.boolean('show_sort', true)) SizedBox(width: gap),
          if (settings.boolean('show_sort', true))
          Expanded(
            child: _ToolbarButton(
              key: const Key('catalog-sort-button'),
              icon: Icons.swap_vert_rounded,
              iconSize: iconSize,
              iconColor: iconColor,
              borderColor: borderColor,
              radius: buttonRadius,
              label: copy.sort,
              onPressed: () async {
                final CatalogSort? selected = await CatalogSortSheet.show(
                  context,
                  selected: state.sort,
                );
                if (selected != null) {
                  await controller.changeSort(selected);
                }
              },
            ),
          ),
          if (settings.boolean('show_result_count', false)) ...<Widget>[
            SizedBox(width: gap),
            Text('${state.totalItems}', style: Theme.of(context).textTheme.labelSmall),
          ],
        ],
      )),
    ));
  }
}

class _CatalogToolbarHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _CatalogToolbarHeaderDelegate({required this.child, required this.extent});

  final Widget child;
  final double extent;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 1 : 0,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _CatalogToolbarHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.extent != extent;
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.iconSize,
    required this.iconColor,
    required this.borderColor,
    required this.radius,
	this.iconOffsetY = 0,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final double iconSize;
  final Color iconColor;
  final Color borderColor;
  final double radius;
	final double iconOffsetY;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: iconColor,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 6),
      ),
      onPressed: onPressed,
	  icon: Transform.translate(offset: Offset(0, iconOffsetY), child: Icon(icon, size: iconSize, weight: 300)),
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
    );
  }
}

class _CatalogProductGrid extends StatelessWidget {
  const _CatalogProductGrid({required this.items, required this.settings});

  final List<CatalogProduct> items;
  final CmsPageComponent settings;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final int responsiveColumns = width >= 760
        ? 4
        : width >= 540
        ? 3
        : 2;
    final int columns = settings.number('columns', 2).round().clamp(1, responsiveColumns).toInt();
    final double gap = settings.number('gap', 12).clamp(0, 32).toDouble();
    final double usableWidth = width - 32 - ((columns - 1) * gap);
    final double cardWidth = usableWidth / columns;
    final double imageRatio = settings.number('image_ratio', 1).clamp(0.6, 1.8).toDouble();
    final double baseExtent = (cardWidth / imageRatio + 103)
        .clamp(250, 336)
        .toDouble();
    final double extent = baseExtent * 0.98;
    final double topSpacing = (width * 0.05).clamp(18, 24).toDouble();

    final double mergeUp = settings
        .number('margin_top', 0)
        .clamp(0, 80)
        .toDouble();
    final double mergeDown = settings
        .number('margin_bottom', 0)
        .clamp(0, 80)
        .toDouble();
    const EdgeInsets outerSpacing = EdgeInsets.zero;
    final EdgeInsetsGeometry innerSpacing = EdgeInsetsDirectional.fromSTEB(
      16 + settings.number('padding_horizontal', 0).clamp(0, 40),
      (topSpacing - mergeUp).clamp(0, topSpacing).toDouble() +
          settings.number('padding_vertical', 0).clamp(0, 40),
      16 + settings.number('padding_horizontal', 0).clamp(0, 40),
      (20 - mergeDown).clamp(0, 20).toDouble() +
          settings.number('padding_vertical', 0).clamp(0, 40),
    );
    return SliverPadding(
      key: const Key('catalog-product-grid-padding'),
      padding: outerSpacing,
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: _cmsElementColor(
            settings.string('background_color', '#FFFFFF'),
          ),
        ),
        sliver: SliverPadding(
          padding: innerSpacing,
          sliver: SliverGrid.builder(
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              mainAxisExtent: extent,
            ),
            itemBuilder: (BuildContext context, int index) {
              final CatalogProduct product = items[index];
              return CatalogProductCard(
                key: ValueKey<int>(product.id),
                product: product,
                settings: settings,
                onTap: () => context.push('/product/${product.id}'),
              );
            },
          ),
        ),
      ),
    );
  }
}

Color _cmsElementColor(String value) {
  final String hex = value.trim().replaceFirst('#', '');
  if (!RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(hex)) return Colors.white;
  return Color(int.parse('FF$hex', radix: 16));
}

class _CatalogLoadingGrid extends StatelessWidget {
  const _CatalogLoadingGrid();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double topSpacing = (MediaQuery.sizeOf(context).width * 0.05)
        .clamp(18, 24)
        .toDouble();
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, topSpacing, 16, 16),
      sliver: SliverGrid.builder(
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 260,
        ),
        itemBuilder: (BuildContext context, int index) => DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({required this.state, required this.onRetry, required this.onLoadMore, required this.settings});

  final CatalogProductListState state;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;
  final CmsPageComponent settings;

  @override
  Widget build(BuildContext context) {
    final CatalogCopy copy = CatalogCopy.of(context);
    if (state.isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(copy.loadingMore),
          ],
        ),
      );
    }
    if (state.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        child: Center(
          child: TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text('${copy.loadMoreFailed} · ${copy.retry}'),
          ),
        ),
      );
    }
    if (!state.hasNextPage) return SizedBox(height: settings.number('pagination_spacing', 16));
    final String mode = settings.string('pagination_mode', 'load_more');
    if (mode == 'automatic') return const SizedBox(height: 16);
    final Color background = _cmsColor(settings.string('pagination_color', '#1F6F61'), Theme.of(context).colorScheme.primary);
    final Color foreground = _cmsColor(settings.string('pagination_text_color', '#FFFFFF'), Colors.white);
    final double height = settings.number('pagination_size', 44).clamp(32, 64).toDouble();
    final double radius = settings.number('pagination_radius', 14).clamp(0, 32).toDouble();
    return Padding(
      padding: EdgeInsets.fromLTRB(16, settings.number('pagination_spacing', 16), 16, 28),
      child: mode == 'numbers'
          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              for (int page = 1; page <= state.totalPages.clamp(1, 7); page++)
                Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: SizedBox.square(dimension: height, child: OutlinedButton(
                  onPressed: page == state.page ? null : (page == state.page + 1 ? onLoadMore : null),
                  style: OutlinedButton.styleFrom(backgroundColor: page == state.page ? background : null, foregroundColor: page == state.page ? foreground : background, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius))),
                  child: Text('$page'),
                ))),
            ])
          : SizedBox(height: height, child: FilledButton(
              onPressed: onLoadMore,
              style: FilledButton.styleFrom(backgroundColor: background, foregroundColor: foreground, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius))),
              child: Text(settings.string('pagination_label', copy.loadMore)),
            )),
    );
  }
}

class _StatusFill extends StatelessWidget {
  const _StatusFill({
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Icon(icon, size: 40, color: colors.onPrimaryContainer),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 18),
                FilledButton.tonalIcon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _friendlyError(CatalogCopy copy, Object error) {
  if (error is CatalogRepositoryException) {
    switch (error.kind) {
      case StoreApiFailureKind.connection:
      case StoreApiFailureKind.timeout:
      case StoreApiFailureKind.certificate:
        return copy.connectionError;
      case StoreApiFailureKind.cancelled:
      case StoreApiFailureKind.configuration:
      case StoreApiFailureKind.unauthorized:
      case StoreApiFailureKind.notFound:
      case StoreApiFailureKind.invalidResponse:
      case StoreApiFailureKind.server:
      case StoreApiFailureKind.unknown:
        return copy.storeError;
    }
  }
  return copy.storeError;
}

Color _cmsColor(String value, Color fallback) {
  final String hex = value.replaceFirst('#', '');
  final int? parsed = int.tryParse(hex, radix: 16);
  return parsed == null || hex.length != 6 ? fallback : Color(0xFF000000 | parsed);
}
