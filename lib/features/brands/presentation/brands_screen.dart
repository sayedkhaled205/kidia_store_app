import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/brands/domain/entities/store_brand.dart';
import 'package:kidia_store_app/features/brands/domain/repositories/brands_repository.dart';
import 'package:kidia_store_app/features/brands/presentation/brands_copy.dart';
import 'package:kidia_store_app/features/brands/presentation/controllers/brands_controller.dart';
import 'package:kidia_store_app/features/brands/presentation/providers/brands_providers.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';

class BrandsScreen extends ConsumerStatefulWidget {
  const BrandsScreen({required this.onBrandTap, super.key});

  final ValueChanged<StoreBrand> onBrandTap;

  @override
  ConsumerState<BrandsScreen> createState() => _BrandsScreenState();
}

class _BrandsScreenState extends ConsumerState<BrandsScreen> {
  late final ScrollController _scrollController;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _searchController = TextEditingController();
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
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 400) {
      ref.read(brandsControllerProvider).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final BrandsController controller = ref.watch(brandsControllerProvider);
    final BrandsCopy copy = BrandsCopy.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(copy.title)),
      body: ListenableBuilder(
        listenable: controller,
        builder: (BuildContext context, Widget? child) => _BrandsContent(
          controller: controller,
          scrollController: _scrollController,
          searchController: _searchController,
          onBrandTap: widget.onBrandTap,
        ),
      ),
    );
  }
}

class _BrandsContent extends StatelessWidget {
  const _BrandsContent({
    required this.controller,
    required this.scrollController,
    required this.searchController,
    required this.onBrandTap,
  });

  final BrandsController controller;
  final ScrollController scrollController;
  final TextEditingController searchController;
  final ValueChanged<StoreBrand> onBrandTap;

  @override
  Widget build(BuildContext context) {
    final BrandsState state = controller.state;
    final BrandsCopy copy = BrandsCopy.of(context);

    return RefreshIndicator(
      onRefresh: () => controller.loadInitial(refresh: true),
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 8),
              child: TextField(
                controller: searchController,
                textInputAction: TextInputAction.search,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: copy.searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: ListenableBuilder(
                    listenable: searchController,
                    builder: (BuildContext context, Widget? child) {
                      if (searchController.text.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return IconButton(
                        tooltip: copy.clearSearch,
                        onPressed: () {
                          searchController.clear();
                          controller.submitSearch('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      );
                    },
                  ),
                ),
                onSubmitted: (String value) {
                  FocusScope.of(context).unfocus();
                  controller.submitSearch(value);
                },
              ),
            ),
          ),
          if (state.isInitialLoading && state.items.isNotEmpty)
            const SliverToBoxAdapter(child: LinearProgressIndicator()),
          if (state.isUnsupported)
            _BrandStatusSliver(
              icon: Icons.extension_off_outlined,
              title: copy.unsupportedTitle,
              description: copy.unsupportedBody,
              actionLabel: copy.retry,
              onAction: controller.loadInitial,
            )
          else if (state.isInitialLoading && state.items.isEmpty)
            const _BrandsLoadingGrid()
          else if (state.error != null && state.items.isEmpty)
            _BrandStatusSliver(
              icon: Icons.cloud_off_outlined,
              title: _friendlyError(copy, state.error!),
              actionLabel: copy.retry,
              onAction: controller.loadInitial,
            )
          else if (state.items.isEmpty)
            _BrandStatusSliver(
              icon: Icons.loyalty_outlined,
              title: state.search.isEmpty ? copy.noBrands : copy.noResults,
              actionLabel: state.search.isEmpty ? null : copy.clearSearch,
              onAction: state.search.isEmpty
                  ? null
                  : () {
                      searchController.clear();
                      controller.submitSearch('');
                    },
            )
          else ...<Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 10),
                child: Text(
                  '${state.totalItems} ${copy.title}',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            _BrandsGrid(items: state.items, onBrandTap: onBrandTap),
            SliverToBoxAdapter(
              child: _BrandsPaginationFooter(
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

class _BrandsGrid extends StatelessWidget {
  const _BrandsGrid({required this.items, required this.onBrandTap});

  final List<StoreBrand> items;
  final ValueChanged<StoreBrand> onBrandTap;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final int columns = width >= 820
        ? 5
        : width >= 620
        ? 4
        : 2;

    return SliverPadding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 20),
      sliver: SliverGrid.builder(
        itemCount: items.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 190,
        ),
        itemBuilder: (BuildContext context, int index) {
          final StoreBrand brand = items[index];
          return _BrandCard(
            key: ValueKey<int>(brand.id),
            brand: brand,
            onTap: () => onBrandTap(brand),
          );
        },
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({required this.brand, required this.onTap, super.key});

  final StoreBrand brand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final BrandsCopy copy = BrandsCopy.of(context);

    return Semantics(
      button: true,
      label: '${brand.name}, ${copy.count(brand.count)}',
      child: Material(
        color: colors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: <Widget>[
                Expanded(child: _BrandLogo(brand: brand)),
                const SizedBox(height: 10),
                Text(
                  brand.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  copy.count(brand.count),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
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

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.brand});

  final StoreBrand brand;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Widget fallback = ColoredBox(
      color: colors.secondaryContainer,
      child: Center(
        child: Text(
          brand.name.characters.first.toUpperCase(),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: colors.onSecondaryContainer,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: brand.image == null
          ? fallback
          : AppNetworkImage(
              imageUrl: brand.image.toString(),
              fit: BoxFit.contain,
              semanticLabel: brand.name,
              backgroundColor: colors.surface,
              errorWidget: fallback,
            ),
    );
  }
}

class _BrandsLoadingGrid extends StatelessWidget {
  const _BrandsLoadingGrid();

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.surfaceContainer;
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverGrid.builder(
        itemCount: 8,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: 190,
        ),
        itemBuilder: (BuildContext context, int index) => DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }
}

class _BrandStatusSliver extends StatelessWidget {
  const _BrandStatusSliver({
    required this.icon,
    required this.title,
    this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
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
                  child: Icon(icon, size: 42, color: colors.onPrimaryContainer),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              if (description != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
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

class _BrandsPaginationFooter extends StatelessWidget {
  const _BrandsPaginationFooter({required this.state, required this.onRetry});

  final BrandsState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final BrandsCopy copy = BrandsCopy.of(context);
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
            label: Text('${copy.moreFailed} · ${copy.retry}'),
          ),
        ),
      );
    }
    return const SizedBox(height: 16);
  }
}

String _friendlyError(BrandsCopy copy, Object error) {
  if (error is BrandsRepositoryException) {
    switch (error.kind) {
      case StoreApiFailureKind.connection:
      case StoreApiFailureKind.timeout:
      case StoreApiFailureKind.certificate:
        return copy.connectionError;
      case StoreApiFailureKind.configuration:
      case StoreApiFailureKind.cancelled:
      case StoreApiFailureKind.unauthorized:
      case StoreApiFailureKind.notFound:
      case StoreApiFailureKind.server:
      case StoreApiFailureKind.invalidResponse:
      case StoreApiFailureKind.unknown:
        return copy.storeError;
    }
  }
  return copy.storeError;
}
