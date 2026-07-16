import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:kidia_store_app/features/catalog/presentation/catalog_copy.dart';
import 'package:kidia_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';
import 'package:kidia_store_app/features/catalog/presentation/providers/catalog_product_list_provider.dart';
import 'package:kidia_store_app/features/catalog/presentation/widgets/catalog_product_card.dart';
import 'package:kidia_store_app/features/catalog/presentation/widgets/catalog_product_filter_sheet.dart';
import 'package:kidia_store_app/features/catalog/presentation/widgets/catalog_sort_sheet.dart';

class CatalogProductListScreen extends StatelessWidget {
  const CatalogProductListScreen({
    required this.request,
    super.key,
    this.showSearchField = true,
  });

  final CatalogProductListRequest request;
  final bool showSearchField;

  @override
  Widget build(BuildContext context) {
    final CatalogCopy copy = CatalogCopy.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          request.title.trim().isEmpty ? copy.products : request.title,
        ),
      ),
      body: CatalogProductListView(
        request: request,
        showSearchField: showSearchField,
      ),
    );
  }
}

class CatalogProductListView extends ConsumerStatefulWidget {
  const CatalogProductListView({
    required this.request,
    super.key,
    this.showSearchField = true,
  });

  final CatalogProductListRequest request;
  final bool showSearchField;

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
    if (position.extentAfter < 520) {
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
  });

  final CatalogProductListController controller;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final bool showSearchField;

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
          if (!controller.isAwaitingSearch)
            SliverToBoxAdapter(
              child: _CatalogToolbar(state: state, controller: controller),
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
            _CatalogProductGrid(items: state.items),
            SliverToBoxAdapter(
              child: _PaginationFooter(
                state: state,
                onRetry: controller.loadMore,
              ),
            ),
          ],
        ],
      ),
    );
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
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: ListenableBuilder(
            listenable: controller,
            builder: (BuildContext context, Widget? child) {
              return controller.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      onPressed: onClear,
                      icon: const Icon(Icons.close_rounded),
                    );
            },
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

class _CatalogToolbar extends StatelessWidget {
  const _CatalogToolbar({required this.state, required this.controller});

  final CatalogProductListState state;
  final CatalogProductListController controller;

  @override
  Widget build(BuildContext context) {
    final CatalogCopy copy = CatalogCopy.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Text(
                copy.productCount(state.totalItems),
                key: ValueKey<int>(state.totalItems),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              final CatalogSort? selected = await CatalogSortSheet.show(
                context,
                selected: state.sort,
              );
              if (selected != null) {
                await controller.changeSort(selected);
              }
            },
            icon: const Icon(Icons.swap_vert_rounded, size: 19),
            label: Text(copy.sort),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: state.filters.activeCount > 0,
            label: Text('${state.filters.activeCount}'),
            child: OutlinedButton.icon(
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
                    );
                if (filters != null) {
                  await controller.applyFilters(filters);
                }
              },
              icon: const Icon(Icons.tune_rounded, size: 19),
              label: Text(copy.filter),
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogProductGrid extends StatelessWidget {
  const _CatalogProductGrid({required this.items});

  final List<CatalogProduct> items;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final int columns = width >= 760
        ? 4
        : width >= 540
        ? 3
        : 2;
    final double usableWidth = width - 32 - ((columns - 1) * 12);
    final double cardWidth = usableWidth / columns;
    final double extent = (cardWidth * 1.25 + 132).clamp(300, 410).toDouble();

    return SliverPadding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 2, 16, 20),
      sliver: SliverGrid.builder(
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: extent,
        ),
        itemBuilder: (BuildContext context, int index) {
          final CatalogProduct product = items[index];
          return CatalogProductCard(
            key: ValueKey<int>(product.id),
            product: product,
            onTap: () => context.push('/product/${product.id}'),
          );
        },
      ),
    );
  }
}

class _CatalogLoadingGrid extends StatelessWidget {
  const _CatalogLoadingGrid();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid.builder(
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 330,
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
  const _PaginationFooter({required this.state, required this.onRetry});

  final CatalogProductListState state;
  final VoidCallback onRetry;

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
    return const SizedBox(height: 16);
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
