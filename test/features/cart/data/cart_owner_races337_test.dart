import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/cart/data/datasources/cart_remote_data_source.dart';
import 'package:mobishop_store_app/features/cart/data/network/cart_api_transport.dart';
import 'package:mobishop_store_app/features/cart/data/network/secure_cart_token_store.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_providers.dart';
import 'cart_test_fixture.dart';

class Auth extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
  void owner(int? id) => state = AsyncData(
    id == null
        ? null
        : AuthSession(
            token: 'synthetic-owner-$id',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
            user: AuthUser(id: id, email: 'fixture@example.invalid'),
          ),
  );
}

class ColdAuth extends AuthController {
  ColdAuth(this.initial);
  final Completer<AuthSession?> initial;
  @override
  Future<AuthSession?> build() => initial.future;
  void session(AuthSession? next) => state = AsyncData(next);
}

AuthSession fixtureSession(int id, String token) => AuthSession(
  token: token,
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  user: AuthUser(id: id, email: 'fixture@example.invalid'),
);
SecureCartTokenStore fixtureStore(
  String host,
  CartTokenOwner? owner, {
  FlutterSecureStorage? storage,
}) => SecureCartTokenStore(
  storeUri: Uri.parse('https://$host.fixture.test'),
  currentOwner: () async => owner,
  storage: storage,
);
void ownerCases() {
  for (final logout in [false, true]) {
    test(
      'pending guest adoption revoked by ${logout ? 'logout' : 'next customer'}',
      () async {
        final first = fixtureStore('adoption-reset-$logout', null);
        await first.restore();
        first.write('synthetic-guest-basket');
        await first.flush();
        final disk = DelayedReadStorage();
        final resumed = fixtureStore(
          'adoption-reset-$logout',
          null,
          storage: disk,
        );
        resumed.setOwner(null);
        final pending = resumed.restore();
        await disk.started.future;
        resumed.setOwner(CartTokenOwner(42, 'synthetic-auth-A'));
        resumed.setOwner(
          logout ? null : CartTokenOwner(73, 'synthetic-auth-B'),
        );
        disk.release.complete();
        await pending;
        await resumed.flush();
        expect(resumed.read(), isNull);
        expect(
          await const FlutterSecureStorage().read(key: resumed.storageKey),
          isNull,
        );
      },
    );
  }
  test(
    'multiple explicit same-owner rotations retain original pending basket',
    () async {
      final first = fixtureStore(
        'multi-rotate',
        CartTokenOwner(42, 'synthetic-auth-A'),
      );
      await first.restore();
      first.write('synthetic-private-basket');
      await first.flush();
      final disk = DelayedReadStorage();
      final resumed = fixtureStore(
        'multi-rotate',
        CartTokenOwner(42, 'synthetic-auth-A'),
        storage: disk,
      );
      final pending = resumed.restore();
      await disk.started.future;
      resumed.setOwner(CartTokenOwner(42, 'synthetic-auth-B'));
      resumed.setOwner(CartTokenOwner(42, 'synthetic-auth-C'));
      disk.release.complete();
      await pending;
      await resumed.flush();
      final restarted = fixtureStore(
        'multi-rotate',
        CartTokenOwner(42, 'synthetic-auth-C'),
      );
      await restarted.restore();
      expect(restarted.read(), 'synthetic-private-basket');
    },
  );
  test(
    'actual provider cold authenticated restore preserves exact owner token',
    () async {
      final owner = CartTokenOwner(42, 'synthetic-auth-A');
      final original = fixtureStore('cold', owner);
      await original.restore();
      original.write('synthetic-private-basket');
      await original.flush();
      final auth = Completer<AuthSession?>();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(() => ColdAuth(auth)),
          cartStoreUriProvider.overrideWithValue(
            Uri.parse('https://cold.fixture.test'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final store =
          container.read(cartTokenStoreProvider) as SecureCartTokenStore;
      final restoring = store.restore();
      auth.complete(fixtureSession(42, 'synthetic-auth-A'));
      await restoring;
      await container.pump();
      await store.flush();
      expect(store.read(), 'synthetic-private-basket');
    },
  );
  test('actual provider guest login restart restores promoted token', () async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(Auth.new),
        cartStoreUriProvider.overrideWithValue(
          Uri.parse('https://promote.fixture.test'),
        ),
      ],
    );
    await container.read(authControllerProvider.future);
    final store =
        container.read(cartTokenStoreProvider) as SecureCartTokenStore;
    await store.restore();
    store.write('synthetic-active-guest');
    await store.flush();
    (container.read(authControllerProvider.notifier) as Auth).owner(42);
    await container.pump();
    await store.flush();
    container.dispose();
    final auth = Completer<AuthSession?>();
    final restarted = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => ColdAuth(auth)),
        cartStoreUriProvider.overrideWithValue(
          Uri.parse('https://promote.fixture.test'),
        ),
      ],
    );
    addTearDown(restarted.dispose);
    final next = restarted.read(cartTokenStoreProvider) as SecureCartTokenStore;
    final pending = next.restore();
    auth.complete(fixtureSession(42, 'synthetic-owner-42'));
    await pending;
    expect(next.read(), 'synthetic-active-guest');
  });
  test(
    'same customer rotation during pending disk read retains basket',
    () async {
      final old = CartTokenOwner(42, 'synthetic-auth-A');
      final next = CartTokenOwner(42, 'synthetic-auth-B');
      final first = fixtureStore('rotation-race', old);
      await first.restore();
      first.write('synthetic-private-basket');
      await first.flush();
      final disk = DelayedReadStorage();
      final resumed = fixtureStore('rotation-race', old, storage: disk);
      final pending = resumed.restore();
      await disk.started.future;
      resumed.setOwner(next);
      disk.release.complete();
      await pending;
      await resumed.flush();
      expect(resumed.read(), 'synthetic-private-basket');
      final restarted = fixtureStore('rotation-race', next);
      await restarted.restore();
      expect(restarted.read(), 'synthetic-private-basket');
    },
  );
  test(
    'known guest login during pending disk read preserves adopted guest basket',
    () async {
      final first = fixtureStore('guest-login-race', null);
      await first.restore();
      first.write('synthetic-active-guest');
      await first.flush();
      final disk = DelayedReadStorage();
      final resumed = fixtureStore('guest-login-race', null, storage: disk);
      resumed.setOwner(null);
      final pending = resumed.restore();
      await disk.started.future;
      resumed.setOwner(CartTokenOwner(42, 'synthetic-auth-A'));
      disk.release.complete();
      await pending;
      await resumed.flush();
      expect(resumed.read(), 'synthetic-active-guest');
    },
  );
  test(
    'different customer while read is pending never adopts private cart',
    () async {
      final old = CartTokenOwner(42, 'synthetic-auth-A');
      final first = fixtureStore('owner-switch-race', old);
      await first.restore();
      first.write('synthetic-private-basket');
      await first.flush();
      final disk = DelayedReadStorage();
      final resumed = fixtureStore('owner-switch-race', old, storage: disk);
      final pending = resumed.restore();
      await disk.started.future;
      resumed.setOwner(CartTokenOwner(73, 'synthetic-auth-B'));
      disk.release.complete();
      await pending;
      await resumed.flush();
      expect(resumed.read(), isNull);
      expect(
        await const FlutterSecureStorage().read(key: resumed.storageKey),
        isNull,
      );
    },
  );
}

class DelayedStorage extends FlutterSecureStorage {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    await super.write(key: key, value: value);
  }
}

class Api implements StoreApiClient, CartApiTransport {
  int posts = 0;
  StoreApiResponse result() => StoreApiResponse(
    data: cartJsonFixture(itemsCount: 1),
    headers: const {
      'cart-token': ['synthetic-token'],
    },
  );
  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async => result();
  @override
  Future<StoreApiResponse> request(
    CartApiMethod method,
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    if (method == CartApiMethod.post) posts++;
    return result();
  }
}

class FailingWriteStorage extends FlutterSecureStorage {
  bool fail = true;
  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (fail) {
      fail = false;
      throw StateError('fixture storage failure');
    }
    await super.write(key: key, value: value);
  }
}

class DelayedReadStorage extends FlutterSecureStorage {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final old = await super.read(key: key);
    if (!started.isCompleted) started.complete();
    await release.future;
    return old;
  }
}

void main() {
  ownerCases();
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'actual token provider isolates login logout and next customer',
    () async {
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(Auth.new),
          cartStoreUriProvider.overrideWithValue(
            Uri.parse('https://fixture.test'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      final auth = container.read(authControllerProvider.notifier) as Auth;
      final store =
          container.read(cartTokenStoreProvider) as SecureCartTokenStore;
      await store.restore();
      store.write('synthetic-guest');
      await store.flush();
      auth.owner(1);
      await container.pump();
      await store.flush();
      expect(store.read(), 'synthetic-guest');
      expect(
        jsonDecode(
          (await const FlutterSecureStorage().read(key: store.storageKey))!,
        )['owner'],
        CartTokenOwner(1, 'synthetic-owner-1').fingerprint,
      );
      store.write('synthetic-owner-cart');
      await store.flush();
      expect(
        jsonDecode(
          (await const FlutterSecureStorage().read(key: store.storageKey))!,
        )['token'],
        'synthetic-owner-cart',
      );
      auth.owner(2);
      await container.pump();
      await store.flush();
      expect(store.read(), isNull);
      store.write('synthetic-second-owner');
      await store.flush();
      auth.owner(null);
      await container.pump();
      await store.flush();
      expect(store.read(), isNull);
      final next = SecureCartTokenStore(
        storeUri: Uri.parse('https://fixture.test'),
        currentOwner: () async => null,
      );
      await next.restore();
      expect(next.read(), isNull);
    },
  );
  test(
    'storage write failure does not poison later clear or restore queue',
    () async {
      final store = SecureCartTokenStore(
        storeUri: Uri.parse('https://failure.fixture.test'),
        currentOwner: () async => null,
        storage: FailingWriteStorage(),
      );
      await store.restore();
      store.write('synthetic-first');
      await expectLater(store.flush(), throwsStateError);
      store.clear();
      await store.flush();
      store.write('synthetic-second');
      await store.flush();
      final restored = SecureCartTokenStore(
        storeUri: Uri.parse('https://failure.fixture.test'),
        currentOwner: () async => null,
      );
      await restored.restore();
      expect(restored.read(), 'synthetic-second');
    },
  );
  test(
    'clear while disk read is pending cannot revive old credential',
    () async {
      final disk = DelayedReadStorage();
      final store = SecureCartTokenStore(
        storeUri: Uri.parse('https://read.fixture.test'),
        currentOwner: () async => null,
        storage: disk,
      );
      await const FlutterSecureStorage().write(
        key: store.storageKey,
        value: jsonEncode({'owner': null, 'token': 'synthetic-old'}),
      );
      final restore = store.restore();
      await disk.started.future;
      store.clear();
      disk.release.complete();
      await restore;
      await store.flush();
      expect(store.read(), isNull);
      expect(
        await const FlutterSecureStorage().read(key: store.storageKey),
        isNull,
      );
    },
  );
  for (final mutation in [false, true]) {
    test(
      'owner change during persisted success flush rejects stale cart mutation=$mutation',
      () async {
        final disk = DelayedStorage();
        final store = SecureCartTokenStore(
          storeUri: Uri.parse('https://flush.fixture.test'),
          currentOwner: () async => null,
          storage: disk,
        );
        await store.restore();
        final api = Api();
        final source = StoreApiCartRemoteDataSource(
          storeApiClient: api,
          transport: api,
          tokenStore: store,
        );
        // Supply an existing token without blocking the operation on its write.
        if (mutation) store.write('synthetic-existing');
        final action = mutation
            ? source.addItem(productId: 1, quantity: 1, variation: [])
            : source.fetchCart();
        final outcome = action.then<Object>(
          (_) => 'success',
          onError: (Object e) => e,
        );
        await disk.started.future;
        await Future<void>.delayed(Duration.zero);
        store.clear();
        store.setOwner(CartTokenOwner(1, 'synthetic-owner-1'));
        disk.release.complete();
        final value = await outcome;
        await store.flush();
        expect(
          value,
          isA<CartRemoteException>(),
          reason:
              'The new flush await is an ownership boundary just like the network await.',
        );
        expect(store.read(), isNull);
        expect(
          await const FlutterSecureStorage().read(key: store.storageKey),
          isNull,
        );
      },
    );
  }
}
