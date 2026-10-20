import '../../features/home/data/home_read_session.dart';
import '../../features/catalog/domain/entities/catalog_category.dart';
import '../../features/catalog/domain/entities/catalog_product.dart';
import '../../features/catalog/domain/queries/catalog_category_query.dart';
import '../../features/catalog/domain/queries/catalog_product_query.dart';
import '../../features/catalog/domain/repositories/catalog_repository.dart';
import '../../features/home/data/models/home_block_model.dart';
import '../../features/home/data/models/home_layout_model.dart';
import '../../features/home/domain/entities/home_block.dart';
import '../../features/home/domain/entities/home_layout.dart';

/// Public selectors retain saved source semantics. Platform-specific modes
/// are additionally constrained by the bundle's bound commerce platform.
void validateCatalogQuery58(
  Map<String, dynamic> query, {
  required bool categories,
}) {
  final kind = categories ? 'categories' : 'products';
  final mode = query['mode'];
  final keys = <String>{'kind', 'mode', 'limit', 'sort'};
  if (mode == 'ids') keys.add('ids');
  if (categories) {
    if (mode == 'parent') keys.add('parent_id');
    keys.add('hide_empty');
  } else {
    if (mode == 'category') keys.add('category_id');
    if (mode == 'search') keys.add('search');
  }
  if (query['kind'] != kind ||
      (categories
          ? !{'all', 'parent', 'ids'}.contains(mode)
          : !{
              'all',
              'latest',
              'featured',
              'on_sale',
              'best_selling',
              'top_rated',
              'ids',
              'category',
              'search',
            }.contains(mode)) ||
      query.keys.any((key) => !keys.contains(key)) ||
      query['limit'] is! int ||
      (query['limit'] as int) < 1 ||
      (query['limit'] as int) > 100 ||
      (query.containsKey('sort') &&
          !{'name', 'relevance', 'newest'}.contains(query['sort'])) ||
      (categories &&
          mode != 'ids' &&
          query['sort'] != null &&
          query['sort'] != 'name') ||
      (categories &&
          query.containsKey('hide_empty') &&
          query['hide_empty'] is! bool)) {
    throw _unsupported();
  }
  if (categories &&
      mode == 'parent' &&
      (query['parent_id'] is! int ||
          (query['parent_id'] as int) < 0 ||
          query['hide_empty'] is! bool)) {
    throw _unsupported();
  }
  if (categories && mode == 'ids' && query['hide_empty'] is! bool) {
    throw _unsupported();
  }
  if (!categories &&
      {
        'latest',
        'featured',
        'on_sale',
        'best_selling',
        'top_rated',
      }.contains(mode) &&
      query['sort'] != 'newest') {
    throw _unsupported();
  }
  if (mode == 'ids') {
    final ids = query['ids'];
    if (ids is! List ||
        ids.isEmpty ||
        ids.length > 100 ||
        ids.length != query['limit'] ||
        ids.any((id) => id is! int || id <= 0) ||
        ids.toSet().length != ids.length ||
        (query.containsKey('sort') && query['sort'] != 'relevance')) {
      throw _unsupported();
    }
  }
  if (mode == 'category' &&
      (query['category_id'] is! int || (query['category_id'] as int) <= 0)) {
    throw _unsupported();
  }
  if (mode == 'search' &&
      (query['search'] is! String ||
          (query['search'] as String).trim().isEmpty ||
          (query['search'] as String).runes.length > 80)) {
    throw _unsupported();
  }
}

Future<HomeLayout> hydrateSavedHome58(
  Map<String, dynamic> saved,
  CatalogRepository repository, {
  required String locale,
}) async {
  final base = HomeLayoutModel.fromJson(saved);
  if (locale != base.locale) {
    throw const FormatException(
      'APP_DESIGN_BUNDLE has no saved Home layout for this locale.',
    );
  }
  final blocks = <HomeBlock>[];
  for (final raw in saved['blocks'] as List) {
    final json = Map<String, dynamic>.from(raw as Map);
    final block = HomeBlockModel.fromJson(json);
    if (!block.enabled || !json.containsKey('catalog_query')) {
      blocks.add(block);
      continue;
    }
    final query = Map<String, dynamic>.from(json['catalog_query'] as Map);
    try {
      if (block is CategoryGridBlock) {
        validateCatalogQuery58(query, categories: true);
        final result = await repository.getCategories(
          CatalogCategoryQuery(
            perPage: query['limit'] as int,
            hideEmpty: query['hide_empty'] == true,
            parentId: query['mode'] == 'parent'
                ? query['parent_id'] as int
                : null,
            includeIds: query['mode'] == 'ids'
                ? (query['ids'] as List).cast<int>()
                : const [],
            sort: query['mode'] == 'ids'
                ? CatalogCategorySort.include
                : CatalogCategorySort.name,
          ),
        );
        if (query['mode'] == 'ids') {
          final ids = (query['ids'] as List).cast<int>();
          if (result.items.any((item) => !ids.contains(item.id)) ||
              result.items.map((item) => item.id).toSet().length !=
                  result.items.length) {
            throw const FormatException(
              'Catalog returned unselected categories.',
            );
          }
          final items = [...result.items]
            ..sort((a, b) => ids.indexOf(a.id).compareTo(ids.indexOf(b.id)));
          blocks.add(_categories(block, items));
          continue;
        }
        blocks.add(_categories(block, result.items));
      } else {
        validateCatalogQuery58(query, categories: false);
        final List<CatalogProduct> products;
        if (query['mode'] == 'ids') {
          products = await Future.wait(
            (query['ids'] as List).cast<int>().map(repository.getProduct),
          );
          for (var index = 0; index < products.length; index++) {
            if (products[index].id != (query['ids'] as List)[index]) {
              throw const FormatException(
                'Catalog detail returned a different selected product.',
              );
            }
          }
        } else {
          final result = await repository.getProducts(
            CatalogProductQuery(
              perPage: query['limit'] as int,
              sort: switch (query['mode']) {
                'best_selling' => CatalogSort.popularity,
                'top_rated' => CatalogSort.rating,
                _ => switch (query['sort']) {
                  'newest' => CatalogSort.newest,
                  'relevance' => CatalogSort.relevance,
                  _ => CatalogSort.name,
                },
              },
              featured: query['mode'] == 'featured' ? true : null,
              onSale: query['mode'] == 'on_sale' ? true : null,
              categoryIds: query['mode'] == 'category'
                  ? [query['category_id'] as int]
                  : const [],
              search: query['mode'] == 'search'
                  ? (query['search'] as String).trim()
                  : '',
            ),
          );
          products = result.items;
        }
        final items = List<HomeProductItem>.unmodifiable(
          products.map(_product),
        );
        blocks.add(
          block is ProductCarouselBlock
              ? _carousel(block, items)
              : _grid(block as ProductGridBlock, items),
        );
      }
    } catch (error) {
      if (!HomeReadSession.isTransient(error)) rethrow;
      blocks.add(CatalogUnavailableBlock(block));
    }
  }
  return HomeLayout(
    version: base.version,
    page: base.page,
    locale: base.locale,
    updatedAt: base.updatedAt,
    blocks: blocks,
  );
}

HomeProductItem _product(CatalogProduct product) {
  final money = product.prices;
  final regular = BigInt.tryParse(money.regularPriceMinor);
  final price = BigInt.tryParse(money.priceMinor);
  final discount =
      regular != null &&
          price != null &&
          regular > BigInt.zero &&
          price >= BigInt.zero &&
          price < regular
      ? (((regular - price) * BigInt.from(100)) ~/ regular).toInt()
      : 0;
  // Exact string minor→decimal conversion. Missing images remain missing so
  // the existing network-image placeholder renders the real item; never drop
  // it or fabricate a merchandise image/product.
  return HomeProductItem(
    id: product.id,
    name: product.name,
    imageUrl: product.primaryImage?.cardSource.toString() ?? '',
    imageUrls: List<String>.unmodifiable(
      product.images.map((image) => image.cardSource.toString()),
    ),
    price: money.decimalAmount(money.priceMinor),
    regularPrice: money.regularPriceMinor.isEmpty
        ? null
        : money.decimalAmount(money.regularPriceMinor),
    currencyCode: money.currencyCode,
    currencySymbol: money.currencySymbol,
    inStock: product.isInStock,
    badge: null,
    rating: product.averageRating,
    reviewCount: product.reviewCount,
    discountPercent: discount,
    action: HomeAction(type: 'product', value: '${product.id}'),
  );
}

CategoryGridBlock _categories(
  CategoryGridBlock b,
  List<CatalogCategory> items,
) => CategoryGridBlock(
  id: b.id,
  enabled: b.enabled,
  presentation: b.presentation,
  title: b.title,
  subtitle: b.subtitle,
  items: List<CategoryItem>.unmodifiable(
    items.map(
      (c) => CategoryItem(
        id: c.id,
        name: c.name,
        imageUrl: c.image?.source.toString() ?? '',
        action: HomeAction(type: 'category', value: '${c.id}'),
      ),
    ),
  ),
  columns: b.columns,
  showNames: b.showNames,
  layout: b.layout,
  itemsAlignment: b.itemsAlignment,
  imageShape: b.imageShape,
  imageSize: b.imageSize,
  gap: b.gap,
  rowGap: b.rowGap,
  labelSize: b.labelSize,
  labelColor: b.labelColor,
);

ProductCarouselBlock _carousel(
  ProductCarouselBlock b,
  List<HomeProductItem> items,
) => ProductCarouselBlock(
  id: b.id,
  enabled: b.enabled,
  presentation: b.presentation,
  title: b.title,
  subtitle: b.subtitle,
  items: items,
  showViewAll: b.showViewAll,
  viewAllLabel: b.viewAllLabel,
  viewAllAction: b.viewAllAction,
  cardStyle: b.cardStyle,
  itemWidth: b.itemWidth,
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

ProductGridBlock _grid(ProductGridBlock b, List<HomeProductItem> items) =>
    ProductGridBlock(
      id: b.id,
      enabled: b.enabled,
      presentation: b.presentation,
      title: b.title,
      subtitle: b.subtitle,
      items: items,
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

FormatException _unsupported() => const FormatException(
  'Unsupported APP_DESIGN_BUNDLE catalog selector; no filter is silently ignored.',
);
