enum CatalogCategorySort { name, count, menuOrder, id, include }

class CatalogCategoryQuery {
  CatalogCategoryQuery({
    int page = 1,
    int perPage = 100,
    String search = '',
    this.parentId,
    this.hideEmpty = true,
    this.sort = CatalogCategorySort.menuOrder,
    Iterable<int> includeIds = const <int>[],
    Iterable<int> excludeIds = const <int>[],
  }) : page = page < 1 ? 1 : page,
       perPage = _pageSize(perPage),
       search = search.trim(),
       includeIds = _positiveIds(includeIds),
       excludeIds = _positiveIds(excludeIds);

  final int page;
  final int perPage;
  final String search;
  final int? parentId;
  final bool hideEmpty;
  final CatalogCategorySort sort;
  final List<int> includeIds;
  final List<int> excludeIds;

  Map<String, dynamic> toStoreApiQuery() {
    final String orderBy;
    switch (sort) {
      case CatalogCategorySort.name:
        orderBy = 'name';
      case CatalogCategorySort.count:
        orderBy = 'count';
      case CatalogCategorySort.menuOrder:
        // WooCommerce Store API category endpoints do not consistently
        // support `menu_order` (older/current stores return rest_invalid_param).
        // `name` is supported across Store API versions and keeps the generic
        // mobile client compatible with any connected WooCommerce store.
        orderBy = 'name';
      case CatalogCategorySort.id:
        orderBy = 'id';
      case CatalogCategorySort.include:
        orderBy = 'include';
    }

    return <String, dynamic>{
      'page': page,
      'per_page': perPage,
      'hide_empty': hideEmpty,
      'orderby': orderBy,
      'order': sort == CatalogCategorySort.count ? 'desc' : 'asc',
      if (search.isNotEmpty) 'search': search,
      if (parentId != null && parentId! >= 0) 'parent': parentId,
      if (includeIds.isNotEmpty) 'include': includeIds.join(','),
      if (excludeIds.isNotEmpty) 'exclude': excludeIds.join(','),
    };
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
}
