class CatalogPage<T> {
  const CatalogPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
    this.discardedItems = 0,
  });

  final List<T> items;
  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;

  /// Invalid individual records are ignored so one bad extension payload does
  /// not break an otherwise usable catalog page.
  final int discardedItems;

  bool get hasNextPage => page < totalPages;
  bool get hasPreviousPage => page > 1;

  CatalogPage<R> map<R>(R Function(T item) transform) {
    return CatalogPage<R>(
      items: List<R>.unmodifiable(items.map(transform)),
      page: page,
      perPage: perPage,
      totalItems: totalItems,
      totalPages: totalPages,
      discardedItems: discardedItems,
    );
  }
}
