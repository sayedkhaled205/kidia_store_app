import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';

/// A wishlist belonging only to this embedded preview session.
///
/// It starts with real products so the Products design can be inspected, then
/// uses the native wishlist controller for removal, undo and product navigation.
/// Changes never reach customer storage and an emptied list is not reseeded.
class CmsPreviewWishlistRepository implements WishlistRepository {
  CmsPreviewWishlistRepository(this.catalogRepository);

  final CatalogRepository catalogRepository;
  List<int>? _ids;
  Future<void>? _initialLoad;

  @override
  Future<List<int>> loadProductIds() async {
    if (_ids == null) {
      await (_initialLoad ??= _seed());
    }
    return List<int>.unmodifiable(_ids!);
  }

  Future<void> _seed() async {
    try {
      final page = await catalogRepository
          .getProducts(CatalogProductQuery(perPage: 20))
          .timeout(const Duration(seconds: 8));
      final List<CatalogProduct> ordered = <CatalogProduct>[
        ...page.items.where((product) => product.primaryImage != null),
        ...page.items.where((product) => product.primaryImage == null),
      ];
      // A mutation completing during the initial request wins over the seed.
      _ids ??= ordered
          .map((product) => product.id)
          .where((id) => id > 0)
          .toSet()
          .take(6)
          .toList(growable: false);
    } finally {
      _initialLoad = null;
    }
  }

  @override
  Future<void> saveProductIds(List<int> productIds) async {
    _ids = productIds.where((id) => id > 0).toSet().toList(growable: false);
  }
}
