import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/app_design/app_design_hydration58.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'home_block_widgets.dart';

/// The shared Kids preset's final, newest-products collection. The initial
/// Home packet remains visible until the first catalog page succeeds.
class KidsHomeProductFeed extends ConsumerStatefulWidget {
  const KidsHomeProductFeed({
    required this.block,
    required this.scrollController,
    required this.onAction,
    super.key,
  });

  final ProductGridBlock block;
  final ScrollController scrollController;
  final ValueChanged<HomeAction> onAction;

  @override
  ConsumerState<KidsHomeProductFeed> createState() =>
      _KidsHomeProductFeedState();
}

class _KidsHomeProductFeedState extends ConsumerState<KidsHomeProductFeed> {
  List<HomeProductItem> _items = const [];
  int _page = 0;
  int _generation = 0;
  bool _loading = false;
  bool _hasMore = true;
  bool _failed = false;
  String? _locale;

  void _reset() {
    _generation++;
    _items = widget.block.items;
    _page = 0;
    _loading = false;
    _hasMore = true;
    _failed = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).toLanguageTag();
    if (_locale != null && _locale != locale) _reset();
    _locale = locale;
  }

  @override
  void initState() {
    super.initState();
    _items = widget.block.items;
    widget.scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void didUpdateWidget(covariant KidsHomeProductFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_onScroll);
      widget.scrollController.addListener(_onScroll);
    }
    // Home refreshes every 15 seconds. Preserve appended pages when the seed
    // is unchanged, but reset when its product order or locale changes.
    if (oldWidget.block.items.map((p) => p.id).join(',') !=
            widget.block.items.map((p) => p.id).join(',') ||
        oldWidget.block.source != widget.block.source ||
        oldWidget.block.categoryId != widget.block.categoryId ||
        oldWidget.block.productIds.join(',') !=
            widget.block.productIds.join(',')) {
      _reset();
    }
  }

  @override
  void dispose() {
    _generation++;
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted ||
        _loading ||
        _failed ||
        !_hasMore ||
        !widget.scrollController.hasClients) {
      return;
    }
    if (widget.scrollController.position.extentAfter < 600) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      if (!const {
        'latest',
        'featured',
        'on_sale',
        'best_selling',
        'top_rated',
        'category',
        'manual',
      }.contains(widget.block.source)) {
        throw const FormatException('This product source cannot be paginated.');
      }
      final page = await ref
          .read(catalogRepositoryProvider)
          .getProducts(
            CatalogProductQuery(
              page: _page + 1,
              perPage: 20,
              sort: switch (widget.block.source) {
                'best_selling' => CatalogSort.popularity,
                'top_rated' => CatalogSort.rating,
                'manual' => CatalogSort.includeOrder,
                _ => CatalogSort.newest,
              },
              categoryIds: widget.block.source == 'category'
                  ? [widget.block.categoryId]
                  : const [],
              includeIds: widget.block.source == 'manual'
                  ? widget.block.productIds
                  : const [],
              featured: widget.block.source == 'featured' ? true : null,
              onSale: widget.block.source == 'on_sale' ? true : null,
            ),
          );
      if (!mounted || generation != _generation) return;
      final unique = <int, HomeProductItem>{
        if (_page > 0)
          for (final item in _items) item.id: item,
        for (final product in page.items)
          product.id: homeProductFromCatalog(product),
      };
      setState(() {
        _items = unique.values.toList(growable: false);
        _page = page.page;
        _hasMore = page.hasNextPage;
        _loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.block;
    final block = ProductGridBlock(
      id: b.id,
      enabled: b.enabled,
      presentation: b.presentation,
      title: b.title,
      subtitle: b.subtitle,
      items: _items,
      columns: b.columns,
      showViewAll: b.showViewAll,
      viewAllLabel: b.viewAllLabel,
      viewAllAction: b.viewAllAction,
      cardStyle: b.cardStyle,
      imageRatio: b.imageRatio,
      cardRadius: b.cardRadius,
      showName: b.showName,
      showPrice: b.showPrice,
      showRegularPrice: b.showRegularPrice,
      showBadge: b.showBadge,
      showRating: b.showRating,
      quickAddEnabled: b.quickAddEnabled,
      contentBottomPadding: b.contentBottomPadding,
      imageSwipeEnabled: b.imageSwipeEnabled,
      quickAddAppearance: b.quickAddAppearance,
      wishlistAppearance: b.wishlistAppearance,
    );
    return Column(
      children: [
        ProductGridBlockWidget(block: block, onAction: widget.onAction),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        if (_failed)
          TextButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.refresh),
            label: Text(
              Localizations.localeOf(context).languageCode == 'ar'
                  ? 'تعذر تحميل المزيد · إعادة المحاولة'
                  : 'Could not load more · Retry',
            ),
          ),
      ],
    );
  }
}
