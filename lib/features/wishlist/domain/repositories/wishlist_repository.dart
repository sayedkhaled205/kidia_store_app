import 'dart:async';

abstract interface class WishlistRepository {
  Future<List<int>> loadProductIds();

  Future<void> saveProductIds(List<int> productIds);
}

abstract interface class AtomicWishlistRepository
    implements WishlistRepository {
  Future<List<int>> updateAtomically(
    FutureOr<List<int>> Function(List<int> current) update,
  );
}

abstract interface class GuestWishlistImporter {
  Future<int> pendingDeviceItemCount();
  Future<void> importDeviceItems();
}

// Product screens and the wishlist can be mounted together. Serialize their
// read/modify/write operations so a stale screen cannot erase a newer save.
final _wishlistWrites = Expando<Future<void>>();
final _wishlistChanges = Expando<StreamController<List<int>>>();

extension WishlistMutation on WishlistRepository {
  Stream<List<int>> get productIdChanges =>
      (_wishlistChanges[this] ??= StreamController<List<int>>.broadcast())
          .stream;

  Future<List<int>> updateProductIds(
    FutureOr<List<int>> Function(List<int> current) update,
  ) {
    final result = Completer<List<int>>();
    _wishlistWrites[this] = (_wishlistWrites[this] ?? Future<void>.value())
        .then((_) async {
          try {
            if (this is AtomicWishlistRepository) {
              final next = await (this as AtomicWishlistRepository)
                  .updateAtomically(update);
              _wishlistChanges[this]?.add(List<int>.unmodifiable(next));
              result.complete(next);
              return;
            }
            final current = await loadProductIds();
            final next = (await update(
              List<int>.of(current),
            )).where((id) => id > 0).toSet().toList(growable: false);
            if (current.length != next.length ||
                Iterable<int>.generate(
                  current.length,
                ).any((i) => current[i] != next[i])) {
              await saveProductIds(next);
              _wishlistChanges[this]?.add(List<int>.unmodifiable(next));
            }
            result.complete(next);
          } catch (error, stack) {
            result.completeError(error, stack);
          }
        });
    return result.future;
  }
}

class WishlistStorageException implements Exception {
  const WishlistStorageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
