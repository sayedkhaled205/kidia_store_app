import 'dart:async';

import 'package:mobishop_store_app/features/account/data/network/customer_account_api_transport.dart';

import '../domain/repositories/wishlist_repository.dart';

/// Signed-in saves live on the customer, never in another user's device cache.
/// Mutations send only the intended delta, so another device's saves survive.
class CustomerWishlistRepository
    implements AtomicWishlistRepository, GuestWishlistImporter {
  CustomerWishlistRepository(this.transport, {this.deviceRepository});

  final DioCustomerAccountApiTransport transport;
  final WishlistRepository? deviceRepository;

  @override
  Future<int> pendingDeviceItemCount() async {
    final local = await deviceRepository?.loadProductIds() ?? <int>[];
    if (local.isEmpty) return 0;
    final remote = await loadProductIds();
    return local.where((id) => !remote.contains(id)).length;
  }

  @override
  Future<void> importDeviceItems() async {
    final local = await deviceRepository?.loadProductIds() ?? <int>[];
    if (local.isNotEmpty) await transport.mutateWishlist(local, []);
  }

  List<int> _ids(Map<String, dynamic> response) {
    final raw = response['product_ids'];
    if (raw is! List || raw.any((id) => id is! int || id <= 0)) {
      throw const WishlistStorageException(
        'The store returned an invalid wishlist.',
      );
    }
    return List<int>.unmodifiable(raw.cast<int>().toSet());
  }

  @override
  Future<List<int>> loadProductIds() async =>
      _ids(await transport.fetchWishlist());

  @override
  Future<List<int>> updateAtomically(
    FutureOr<List<int>> Function(List<int>) update,
  ) async {
    final current = await loadProductIds();
    final next = (await update(
      List<int>.of(current),
    )).where((id) => id > 0).toSet().toList();
    final add = next.where((id) => !current.contains(id)).toList();
    final remove = current.where((id) => !next.contains(id)).toList();
    return add.isEmpty && remove.isEmpty
        ? current
        : _ids(await transport.mutateWishlist(add, remove));
  }

  @override
  Future<void> saveProductIds(List<int> productIds) async {
    await updateAtomically((_) => productIds);
  }
}
