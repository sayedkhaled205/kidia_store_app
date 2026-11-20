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
  Future<List<int>>? _pendingRead;
  int _readRevision = 0;

  void _invalidateRead() {
    _readRevision++;
    _pendingRead = null;
  }

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
    if (local.isEmpty) return;
    _invalidateRead();
    try {
      await transport.mutateWishlist(local, []);
    } finally {
      _invalidateRead();
    }
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
  Future<List<int>> loadProductIds() async {
    final pending = _pendingRead;
    if (pending != null) return pending;
    final request = _readProductIds(_readRevision);
    _pendingRead = request;
    try {
      return await request;
    } finally {
      if (identical(_pendingRead, request)) _pendingRead = null;
    }
  }

  Future<List<int>> _readProductIds(int revision) async {
    final ids = _ids(await transport.fetchWishlist());
    // A write may have completed while the shared card read was in flight.
    // No settled cache: only overlapping readers of this account share work.
    return revision == _readRevision ? ids : await loadProductIds();
  }

  @override
  Future<List<int>> updateAtomically(
    FutureOr<List<int>> Function(List<int>) update,
  ) async {
    _invalidateRead();
    try {
      // Mutations always read fresh state, never a request begun by an old card.
      final current = _ids(await transport.fetchWishlist());
      final next = (await update(
        List<int>.of(current),
      )).where((id) => id > 0).toSet().toList();
      final add = next.where((id) => !current.contains(id)).toList();
      final remove = current.where((id) => !next.contains(id)).toList();
      return add.isEmpty && remove.isEmpty
          ? current
          : _ids(await transport.mutateWishlist(add, remove));
    } finally {
      _invalidateRead();
    }
  }

  @override
  Future<void> saveProductIds(List<int> productIds) async {
    await updateAtomically((_) => productIds);
  }
}
