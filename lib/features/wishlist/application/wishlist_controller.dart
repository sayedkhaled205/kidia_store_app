import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:kidia_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';

enum WishlistStatus { initial, loading, ready, empty, failure }

class WishlistController extends ChangeNotifier {
  WishlistController({
    required this.repository,
    required this.catalogRepository,
  });

  static const int _hydrationBatchSize = 100;

  final WishlistRepository repository;
  final CatalogRepository catalogRepository;

  WishlistStatus _status = WishlistStatus.initial;
  List<int> _productIds = const <int>[];
  List<CatalogProduct> _products = const <CatalogProduct>[];
  String? _loadError;
  String? _mutationError;
  bool _isMutating = false;
  bool _isDisposed = false;
  int _requestSerial = 0;
  Future<void> _mutationTail = Future<void>.value();

  WishlistStatus get status => _status;
  List<int> get productIds => List<int>.unmodifiable(_productIds);
  List<CatalogProduct> get products =>
      List<CatalogProduct>.unmodifiable(_products);
  String? get loadError => _loadError;
  String? get mutationError => _mutationError;
  bool get isMutating => _isMutating;
  bool get isEmpty => _productIds.isEmpty;
  int get length => _productIds.length;

  bool contains(int productId) => _productIds.contains(productId);

  Future<void> load() async {
    await _mutationTail;
    if (_isDisposed) {
      return;
    }
    final int serial = ++_requestSerial;
    _status = WishlistStatus.loading;
    _loadError = null;
    _mutationError = null;
    _notify();

    try {
      final List<int> storedIds = _normalizeIds(
        await repository.loadProductIds(),
      );
      if (!_canCommit(serial)) {
        return;
      }
      if (storedIds.isEmpty) {
        _productIds = const <int>[];
        _products = const <CatalogProduct>[];
        _status = WishlistStatus.empty;
        _notify();
        return;
      }

      final List<CatalogProduct> hydrated = await _hydrate(storedIds);
      if (!_canCommit(serial)) {
        return;
      }
      final Map<int, CatalogProduct> byId = <int, CatalogProduct>{
        for (final CatalogProduct product in hydrated) product.id: product,
      };
      final List<int> availableIds = storedIds
          .where(byId.containsKey)
          .toList(growable: false);
      _productIds = List<int>.unmodifiable(availableIds);
      _products = List<CatalogProduct>.unmodifiable(
        availableIds.map((int productId) => byId[productId]!),
      );
      _status = availableIds.isEmpty
          ? WishlistStatus.empty
          : WishlistStatus.ready;
      _notify();

      if (availableIds.length != storedIds.length) {
        _scheduleStaleIdCleanup(serial, availableIds);
      }
    } catch (error) {
      if (!_canCommit(serial)) {
        return;
      }
      _productIds = const <int>[];
      _products = const <CatalogProduct>[];
      _loadError = _messageFor(
        error,
        fallback: 'Unable to load your saved items. Please try again.',
      );
      _status = WishlistStatus.failure;
      _notify();
    }
  }

  Future<void> refresh() => load();

  Future<bool> add(int productId, {CatalogProduct? product}) {
    return _enqueueMutation(() => _addNow(productId, product: product));
  }

  Future<bool> remove(int productId) {
    return _enqueueMutation(() => _removeNow(productId));
  }

  Future<bool> toggle(int productId, {CatalogProduct? product}) {
    return _enqueueMutation(() {
      return contains(productId)
          ? _removeNow(productId)
          : _addNow(productId, product: product);
    });
  }

  Future<bool> _addNow(int productId, {CatalogProduct? product}) async {
    if (_isDisposed || productId <= 0 || contains(productId)) {
      return false;
    }
    _requestSerial++;
    _beginMutation();
    try {
      CatalogProduct resolvedProduct = product?.id == productId
          ? product!
          : await catalogRepository.getProduct(productId);
      if (resolvedProduct.id != productId) {
        throw const WishlistStorageException(
          'The store returned the wrong product for this saved item.',
        );
      }
      final List<int> nextIds = <int>[productId, ..._productIds];
      await repository.saveProductIds(nextIds);
      if (_isDisposed) {
        return false;
      }

      final Map<int, CatalogProduct> currentProducts = <int, CatalogProduct>{
        for (final CatalogProduct item in _products) item.id: item,
      };
      currentProducts[productId] = resolvedProduct;
      _productIds = List<int>.unmodifiable(nextIds);
      _products = List<CatalogProduct>.unmodifiable(
        nextIds
            .map((int id) => currentProducts[id])
            .whereType<CatalogProduct>(),
      );
      _status = WishlistStatus.ready;
      return true;
    } catch (error) {
      _mutationError = _messageFor(
        error,
        fallback: 'Unable to save this item on your device.',
      );
      return false;
    } finally {
      _endMutation();
    }
  }

  Future<bool> _removeNow(int productId) async {
    if (_isDisposed || productId <= 0 || !contains(productId)) {
      return false;
    }
    _requestSerial++;
    _beginMutation();
    try {
      final List<int> nextIds = _productIds
          .where((int id) => id != productId)
          .toList(growable: false);
      await repository.saveProductIds(nextIds);
      if (_isDisposed) {
        return false;
      }
      _productIds = List<int>.unmodifiable(nextIds);
      _products = List<CatalogProduct>.unmodifiable(
        _products.where((CatalogProduct item) => item.id != productId),
      );
      _status = nextIds.isEmpty ? WishlistStatus.empty : WishlistStatus.ready;
      return true;
    } catch (error) {
      _mutationError = _messageFor(
        error,
        fallback: 'Unable to remove this item from your device.',
      );
      return false;
    } finally {
      _endMutation();
    }
  }

  Future<List<CatalogProduct>> _hydrate(List<int> productIds) async {
    final List<CatalogProduct> products = <CatalogProduct>[];
    for (
      int start = 0;
      start < productIds.length;
      start += _hydrationBatchSize
    ) {
      final int end = start + _hydrationBatchSize < productIds.length
          ? start + _hydrationBatchSize
          : productIds.length;
      final List<int> batch = productIds.sublist(start, end);
      final CatalogPage<CatalogProduct> page = await catalogRepository
          .getProducts(
            CatalogProductQuery(
              includeIds: batch,
              perPage: batch.length,
              sort: CatalogSort.includeOrder,
            ),
          );
      final Set<int> requestedIds = batch.toSet();
      products.addAll(
        page.items.where(
          (CatalogProduct product) => requestedIds.contains(product.id),
        ),
      );
    }
    return List<CatalogProduct>.unmodifiable(products);
  }

  Future<bool> _enqueueMutation(Future<bool> Function() action) {
    final Completer<bool> completer = Completer<bool>();
    _mutationTail = _mutationTail.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void _scheduleStaleIdCleanup(int serial, List<int> availableIds) {
    unawaited(
      _enqueueMutation(() async {
        if (!_canCommit(serial)) {
          return false;
        }
        try {
          await repository.saveProductIds(availableIds);
          return true;
        } catch (error) {
          if (_canCommit(serial)) {
            _mutationError = _messageFor(
              error,
              fallback: 'Unable to update saved items on this device.',
            );
            _notify();
          }
          return false;
        }
      }),
    );
  }

  void _beginMutation() {
    _isMutating = true;
    _mutationError = null;
    _notify();
  }

  void _endMutation() {
    if (_isDisposed) {
      return;
    }
    _isMutating = false;
    _notify();
  }

  void clearMutationError() {
    if (_mutationError == null) {
      return;
    }
    _mutationError = null;
    _notify();
  }

  static List<int> _normalizeIds(Iterable<int> productIds) {
    final LinkedHashSet<int> result = LinkedHashSet<int>();
    for (final int productId in productIds) {
      if (productId > 0) {
        result.add(productId);
      }
    }
    return List<int>.unmodifiable(result);
  }

  static String _messageFor(Object error, {required String fallback}) {
    if (error is WishlistStorageException && error.message.trim().isNotEmpty) {
      return error.message.trim();
    }
    if (error is CatalogRepositoryException &&
        error.message.trim().isNotEmpty) {
      return error.message.trim();
    }
    return fallback;
  }

  bool _canCommit(int serial) => !_isDisposed && serial == _requestSerial;

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestSerial++;
    super.dispose();
  }
}
