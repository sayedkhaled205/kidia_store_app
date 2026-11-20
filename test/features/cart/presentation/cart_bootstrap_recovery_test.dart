import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/cart/data/models/cart_model.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_item.dart';
import 'package:mobishop_store_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:mobishop_store_app/features/cart/presentation/adapters/product_purchase_selection.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_providers.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_state_providers.dart';

import '../data/cart_test_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final kind in [
    CartFailureKind.connection,
    CartFailureKind.timeout,
    CartFailureKind.server,
  ]) {
    test('new Add recovers failed initial $kind read without replay', () async {
      final repository = _Repository(kind);
      final container = await _container(repository);
      final controller = container.read(cartControllerProvider.notifier);
      final first = controller.addSelection(_selection());
      repository.readGate.completeError(repository.error);
      expect((await first).succeeded, false);
      expect(repository.reads, 1);
      expect(repository.writes, 0);

      repository.readGate = Completer<Cart>()..complete(repository.cart);
      expect((await controller.addSelection(_selection())).succeeded, true);
      expect(repository.reads, 2);
      expect(repository.writes, 1);
    });
  }

  test('still offline makes one fresh read per deliberate attempt', () async {
    final repository = _Repository(CartFailureKind.connection);
    final container = await _container(repository);
    final controller = container.read(cartControllerProvider.notifier);
    final first = controller.addSelection(_selection());
    repository.readGate.completeError(repository.error);
    await first;
    repository.readGate = Completer<Cart>();
    final second = controller.addSelection(_selection());
    repository.readGate.completeError(repository.error);
    expect((await second).succeeded, false);
    expect(repository.reads, 2);
    expect(repository.writes, 0);
  });

  for (final kind in [
    CartFailureKind.unauthorized,
    CartFailureKind.invalidInput,
  ]) {
    test('new Add does not retry definitive $kind errors', () async {
      final repository = _Repository(kind);
      final container = await _container(repository);
      final controller = container.read(cartControllerProvider.notifier);
      final first = controller.addSelection(_selection());
      repository.readGate.completeError(repository.error);
      await first;
      expect((await controller.addSelection(_selection())).succeeded, false);
      expect(repository.reads, 1);
      expect(repository.writes, 0);
    });
  }

  test(
    'concurrent Add taps share recovery and only one mutation runs',
    () async {
      final repository = _Repository(CartFailureKind.connection);
      final container = await _container(repository);
      final controller = container.read(cartControllerProvider.notifier);
      final first = controller.addSelection(_selection());
      repository.readGate.completeError(repository.error);
      await first;
      repository.readGate = Completer<Cart>();
      final second = controller.addSelection(_selection());
      final third = controller.addSelection(_selection());
      repository.readGate.complete(repository.cart);
      final results = await Future.wait([second, third]);
      expect(results.where((result) => result.succeeded), hasLength(1));
      expect(repository.reads, 2);
      expect(repository.writes, 1);
    },
  );

  test('recovery cannot submit for a changed customer', () async {
    final repository = _Repository(CartFailureKind.connection);
    final container = await _container(repository);
    final controller = container.read(cartControllerProvider.notifier);
    final first = controller.addSelection(_selection());
    repository.readGate.completeError(repository.error);
    await first;
    repository.readGate = Completer<Cart>();
    final second = controller.addSelection(_selection());
    (container.read(authControllerProvider.notifier) as _Auth).setOwner();
    repository.readGate.complete(repository.cart);
    expect((await second).succeeded, false);
    expect(repository.writes, 0);
  });

  test('disposing during recovery never submits or throws', () async {
    final repository = _Repository(CartFailureKind.connection);
    final container = await _container(repository, dispose: false);
    final controller = container.read(cartControllerProvider.notifier);
    final first = controller.addSelection(_selection());
    repository.readGate.completeError(repository.error);
    await first;
    repository.readGate = Completer<Cart>();
    final second = controller.addSelection(_selection());
    container.dispose();
    repository.readGate.complete(repository.cart);
    expect((await second).succeeded, false);
    expect(repository.writes, 0);
  });
}

ProductPurchaseSelection _selection() =>
    ProductPurchaseSelection(productId: 38);

Future<ProviderContainer> _container(
  _Repository repository, {
  bool dispose = true,
}) async {
  final container = ProviderContainer(
    overrides: [
      cartRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(_Auth.new),
    ],
  );
  if (dispose) addTearDown(container.dispose);
  await container.read(authControllerProvider.future);
  container.listen(cartControllerProvider, (_, _) {});
  return container;
}

class _Auth extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
  void setOwner() => state = AsyncData(
    AuthSession(
      token: 'test-owner',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      user: const AuthUser(
        id: 2,
        email: 'test@example.invalid',
        displayName: 'Test',
      ),
    ),
  );
}

class _Repository implements CartRepository {
  _Repository(CartFailureKind kind)
    : error = CartRepositoryException(kind: kind, message: 'Read failed');
  final CartRepositoryException error;
  final Cart cart = CartModel.fromJson(cartJsonFixture()).toEntity();
  Completer<Cart> readGate = Completer<Cart>();
  int reads = 0;
  int writes = 0;
  @override
  Future<Cart> getCart() {
    reads++;
    return readGate.future;
  }

  @override
  Future<Cart> addItem({
    required int productId,
    int quantity = 1,
    List<CartItemVariation> variation = const [],
  }) async {
    writes++;
    return cart;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
