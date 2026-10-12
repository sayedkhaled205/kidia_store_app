class CatalogPage<T> {
  const CatalogPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
    this.discardedItems = 0,
    this.cursorPagination = false,
    this.cursorHasNextPage = false,
    this.cursorHasPreviousPage = false,
    this.nextCursor,
    this.previousCursor,
  });

  final List<T> items;
  final int page;
  final int perPage;

  /// Null means the platform does not expose an exact total. Never substitute
  /// a loaded-page count or zero for Shopify's unknown catalog total.
  final int? totalItems;
  final int? totalPages;
  final bool cursorPagination;
  final bool cursorHasNextPage;
  final bool cursorHasPreviousPage;
  final String? nextCursor;
  final String? previousCursor;

  /// Invalid individual records are ignored so one bad extension payload does
  /// not break an otherwise usable catalog page.
  final int discardedItems;

  bool get hasKnownTotals => totalItems != null && totalPages != null;
  bool get hasNextPage =>
      cursorPagination ? cursorHasNextPage : page < (totalPages ?? 0);
  bool get hasPreviousPage =>
      cursorPagination ? cursorHasPreviousPage : page > 1;

  CatalogPage<R> map<R>(R Function(T item) transform) {
    return CatalogPage<R>(
      items: List<R>.unmodifiable(items.map(transform)),
      page: page,
      perPage: perPage,
      totalItems: totalItems,
      totalPages: totalPages,
      discardedItems: discardedItems,
      cursorPagination: cursorPagination,
      cursorHasNextPage: cursorHasNextPage,
      cursorHasPreviousPage: cursorHasPreviousPage,
      nextCursor: nextCursor,
      previousCursor: previousCursor,
    );
  }
}
