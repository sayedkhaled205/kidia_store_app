abstract interface class WishlistRepository {
  Future<List<int>> loadProductIds();

  Future<void> saveProductIds(List<int> productIds);
}

class WishlistStorageException implements Exception {
  const WishlistStorageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
