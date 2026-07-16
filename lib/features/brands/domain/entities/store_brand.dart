class StoreBrand {
  const StoreBrand({
    required this.id,
    required this.name,
    required this.slug,
    this.count = 0,
    this.image,
  });

  final int id;
  final String name;
  final String slug;
  final int count;
  final Uri? image;
}

class StoreBrandPage {
  const StoreBrandPage({
    required this.items,
    required this.page,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
    this.discardedItems = 0,
  });

  final List<StoreBrand> items;
  final int page;
  final int perPage;
  final int totalItems;
  final int totalPages;
  final int discardedItems;

  bool get hasNextPage => page < totalPages;
}
