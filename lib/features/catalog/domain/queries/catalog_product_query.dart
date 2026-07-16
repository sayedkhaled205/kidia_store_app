enum CatalogSort {
  relevance,
  newest,
  includeOrder,
  priceLowToHigh,
  priceHighToLow,
  popularity,
  rating,
  name,
}

enum CatalogStockFilter { inStock, outOfStock, onBackorder }

enum CatalogAttributeOperator { any, all }

enum CatalogProductType { simple, grouped, external, variable, variation }

class CatalogAttributeFilter {
  CatalogAttributeFilter({
    required String taxonomy,
    required Iterable<String> terms,
    this.operator = CatalogAttributeOperator.any,
  }) : taxonomy = taxonomy.trim(),
       terms = List<String>.unmodifiable(
         terms
             .map((String term) => term.trim())
             .where((String term) => term.isNotEmpty)
             .toSet(),
       );

  final String taxonomy;
  final List<String> terms;
  final CatalogAttributeOperator operator;

  bool get isValid => taxonomy.isNotEmpty && terms.isNotEmpty;
}

class CatalogProductQuery {
  CatalogProductQuery({
    int page = 1,
    int perPage = 20,
    String search = '',
    this.sort = CatalogSort.relevance,
    Iterable<int> includeIds = const <int>[],
    Iterable<int> excludeIds = const <int>[],
    Iterable<int> categoryIds = const <int>[],
    Iterable<int> tagIds = const <int>[],
    Iterable<int> brandIds = const <int>[],
    Iterable<int> parentIds = const <int>[],
    Iterable<CatalogStockFilter> stock = const <CatalogStockFilter>[],
    Iterable<CatalogAttributeFilter> attributes =
        const <CatalogAttributeFilter>[],
    String minimumPriceMinor = '',
    String maximumPriceMinor = '',
    this.onSale,
    this.featured,
    this.productType,
  }) : page = page < 1 ? 1 : page,
       perPage = _pageSize(perPage),
       search = search.trim(),
       includeIds = _positiveIds(includeIds),
       excludeIds = _positiveIds(excludeIds),
       categoryIds = _positiveIds(categoryIds),
       tagIds = _positiveIds(tagIds),
       brandIds = _positiveIds(brandIds),
       parentIds = _positiveIds(parentIds),
       stock = List<CatalogStockFilter>.unmodifiable(stock.toSet()),
       attributes = List<CatalogAttributeFilter>.unmodifiable(
         attributes.where((CatalogAttributeFilter item) => item.isValid),
       ),
       minimumPriceMinor = _minorAmount(minimumPriceMinor),
       maximumPriceMinor = _minorAmount(maximumPriceMinor);

  final int page;
  final int perPage;
  final String search;
  final CatalogSort sort;
  final List<int> includeIds;
  final List<int> excludeIds;
  final List<int> categoryIds;
  final List<int> tagIds;

  /// Empty on older WooCommerce stores that do not expose product brands.
  final List<int> brandIds;
  final List<int> parentIds;
  final List<CatalogStockFilter> stock;
  final List<CatalogAttributeFilter> attributes;
  final String minimumPriceMinor;
  final String maximumPriceMinor;
  final bool? onSale;
  final bool? featured;
  final CatalogProductType? productType;

  Map<String, dynamic> toStoreApiQuery() {
    final Map<String, dynamic> query = <String, dynamic>{
      'page': page,
      'per_page': perPage,
      if (search.isNotEmpty) 'search': search,
      if (includeIds.isNotEmpty) 'include': includeIds.join(','),
      if (excludeIds.isNotEmpty) 'exclude': excludeIds.join(','),
      if (categoryIds.isNotEmpty) 'category': categoryIds.join(','),
      if (tagIds.isNotEmpty) 'tag': tagIds.join(','),
      if (brandIds.isNotEmpty) 'brand': brandIds.join(','),
      if (parentIds.isNotEmpty) 'parent': parentIds.join(','),
      if (stock.isNotEmpty)
        'stock_status[]': stock.map(_stockValue).toList(growable: false),
      if (minimumPriceMinor.isNotEmpty) 'min_price': minimumPriceMinor,
      if (maximumPriceMinor.isNotEmpty) 'max_price': maximumPriceMinor,
      if (onSale != null) 'on_sale': onSale,
      if (featured != null) 'featured': featured,
      if (productType != null) 'type': productType!.name,
      ..._sortQuery(sort, hasSearch: search.isNotEmpty),
    };

    for (int index = 0; index < attributes.length; index++) {
      final CatalogAttributeFilter filter = attributes[index];
      query['attributes[$index][attribute]'] = filter.taxonomy;
      query['attributes[$index][slug]'] = filter.terms.join(',');
      query['attributes[$index][operator]'] =
          filter.operator == CatalogAttributeOperator.all ? 'and' : 'in';
    }

    return query;
  }

  static Map<String, String> _sortQuery(
    CatalogSort sort, {
    required bool hasSearch,
  }) {
    switch (sort) {
      case CatalogSort.relevance:
        return hasSearch
            ? const <String, String>{}
            : const <String, String>{'orderby': 'date', 'order': 'desc'};
      case CatalogSort.newest:
        return const <String, String>{'orderby': 'date', 'order': 'desc'};
      case CatalogSort.includeOrder:
        return const <String, String>{'orderby': 'include', 'order': 'asc'};
      case CatalogSort.priceLowToHigh:
        return const <String, String>{'orderby': 'price', 'order': 'asc'};
      case CatalogSort.priceHighToLow:
        return const <String, String>{'orderby': 'price', 'order': 'desc'};
      case CatalogSort.popularity:
        return const <String, String>{'orderby': 'popularity', 'order': 'desc'};
      case CatalogSort.rating:
        return const <String, String>{'orderby': 'rating', 'order': 'desc'};
      case CatalogSort.name:
        return const <String, String>{'orderby': 'title', 'order': 'asc'};
    }
  }

  static List<int> _positiveIds(Iterable<int> source) {
    return List<int>.unmodifiable(source.where((int id) => id > 0).toSet());
  }

  static int _pageSize(int source) {
    if (source < 1) {
      return 1;
    }
    return source > 100 ? 100 : source;
  }

  static String _minorAmount(String source) {
    final String value = source.trim();
    return RegExp(r'^\d+$').hasMatch(value) ? value : '';
  }

  static String _stockValue(CatalogStockFilter value) {
    switch (value) {
      case CatalogStockFilter.inStock:
        return 'instock';
      case CatalogStockFilter.outOfStock:
        return 'outofstock';
      case CatalogStockFilter.onBackorder:
        return 'onbackorder';
    }
  }
}
