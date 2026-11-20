import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:mobishop_store_app/features/account/data/network/customer_account_api_transport.dart';
import 'package:mobishop_store_app/features/wishlist/data/customer_wishlist_repository.dart';
import 'package:mobishop_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';

class Server {
  List<int> ids = [1];
}

class DeviceWishlist implements WishlistRepository {
  List<int> ids = [8, 9];
  @override
  Future<List<int>> loadProductIds() async => List<int>.of(ids);
  @override
  Future<void> saveProductIds(List<int> productIds) async {
    ids = productIds;
  }
}

class Transport extends DioCustomerAccountApiTransport {
  Transport(this.server)
    : super(
        storeUri: Uri.parse('https://shop.example'),
        authTokenReader: () => 'session',
      );
  final Server server;
  void Function()? beforeMutation;
  @override
  Future<Map<String, dynamic>> fetchWishlist() async => {
    'product_ids': List<int>.of(server.ids),
  };
  @override
  Future<Map<String, dynamic>> mutateWishlist(
    List<int> add,
    List<int> remove,
  ) async {
    beforeMutation?.call();
    beforeMutation = null;
    server.ids = {
      ...add,
      ...server.ids,
    }.where((id) => !remove.contains(id)).toList();
    return {'product_ids': server.ids};
  }
}

class HeldTransport extends Transport {
  HeldTransport(super.server);
  final reads = <Completer<Map<String, dynamic>>>[];
  @override
  Future<Map<String, dynamic>> fetchWishlist() {
    final pending = Completer<Map<String, dynamic>>();
    reads.add(pending);
    return pending.future;
  }

  void finish(int index, List<int> ids) =>
      reads[index].complete({'product_ids': ids});
}

void main() {
  test(
    'old failed read cannot clear a newer pending request after a failed write',
    () async {
      final transport = HeldTransport(Server());
      final repository = CustomerWishlistRepository(transport);
      final oldFailure = expectLater(
        repository.loadProductIds(),
        throwsStateError,
      );
      final mutationFailure = expectLater(
        repository.updateAtomically((ids) => [2, ...ids]),
        throwsStateError,
      );
      transport.reads[1].completeError(StateError('write pre-read failed'));
      await mutationFailure;
      final fresh = repository.loadProductIds();
      transport.reads[0].completeError(StateError('old read failed'));
      await oldFailure;
      final follower = repository.loadProductIds();
      expect(transport.reads.length, 3);
      transport.finish(2, [7]);
      expect(await Future.wait([fresh, follower]), everyElement([7]));
    },
  );

  test(
    'concurrent hearts share one read but later reads remain fresh',
    () async {
      final transport = HeldTransport(Server());
      final repository = CustomerWishlistRepository(transport);
      final hearts = List.generate(12, (_) => repository.loadProductIds());
      expect(transport.reads.length, 1);
      transport.finish(0, [1, 2]);
      expect(await Future.wait(hearts), everyElement([1, 2]));
      final next = repository.loadProductIds();
      expect(transport.reads.length, 2);
      transport.finish(1, [3]);
      expect(await next, [3]);
    },
  );

  test('shared failure allows a new request', () async {
    final transport = HeldTransport(Server());
    final repository = CustomerWishlistRepository(transport);
    final first = expectLater(repository.loadProductIds(), throwsStateError);
    final second = expectLater(repository.loadProductIds(), throwsStateError);
    expect(transport.reads.length, 1);
    transport.reads[0].completeError(StateError('offline'));
    await Future.wait([first, second]);
    final retry = repository.loadProductIds();
    expect(transport.reads.length, 2);
    transport.finish(1, [2]);
    expect(await retry, [2]);
  });

  test('mutation reads fresh state and fences a late shared read', () async {
    final transport = HeldTransport(Server());
    final repository = CustomerWishlistRepository(transport);
    final old = repository.loadProductIds();
    final oldFollower = repository.loadProductIds();
    final mutation = repository.updateAtomically((ids) => [2, ...ids]);
    expect(transport.reads.length, 2);
    transport.finish(1, [1]);
    expect(await mutation, [2, 1]);
    final fresh = repository.loadProductIds();
    expect(transport.reads.length, 3);
    transport.finish(0, [1]);
    await Future<void>.delayed(Duration.zero);
    // The old response must join the new generation, not clear or expose it.
    final follower = repository.loadProductIds();
    expect(transport.reads.length, 3);
    transport.finish(2, [2, 1]);
    expect(
      await Future.wait([old, oldFollower, fresh, follower]),
      everyElement([2, 1]),
    );
  });

  test('explicit device import invalidates pending remote snapshots', () async {
    final transport = HeldTransport(Server());
    final device = DeviceWishlist();
    final repository = CustomerWishlistRepository(
      transport,
      deviceRepository: device,
    );
    final old = repository.loadProductIds();
    await repository.importDeviceItems();
    transport.finish(0, [1]);
    await Future<void>.delayed(Duration.zero);
    expect(transport.reads.length, 2);
    transport.finish(1, [8, 9, 1]);
    expect(await old, [8, 9, 1]);
    expect(device.ids, [8, 9]);
  });

  test(
    'legacy device favorites require explicit import and stay preserved',
    () async {
      final server = Server();
      final device = DeviceWishlist();
      final repository = CustomerWishlistRepository(
        Transport(server),
        deviceRepository: device,
      );
      expect(await repository.loadProductIds(), [1]);
      expect(await repository.pendingDeviceItemCount(), 2);
      await repository.importDeviceItems();
      expect(await repository.loadProductIds(), [8, 9, 1]);
      expect(await repository.pendingDeviceItemCount(), 0);
      expect(device.ids, [8, 9]);
    },
  );
  test(
    'a late wishlist response is rejected after switching accounts',
    () async {
      var token = 'old-session';
      final requested = Completer<RequestInterceptorHandler>();
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requested.complete(handler);
            },
          ),
        );
      final transport = DioCustomerAccountApiTransport(
        storeUri: Uri.parse('https://shop.example'),
        authTokenReader: () => token,
        dio: dio,
      );
      final repository = CustomerWishlistRepository(transport);
      final pending = repository.loadProductIds();
      final second = repository.loadProductIds();
      final result = expectLater(
        pending,
        throwsA(isA<CustomerAccountTransportException>()),
      );
      final secondResult = expectLater(
        second,
        throwsA(isA<CustomerAccountTransportException>()),
      );
      final handler = await requested.future;
      token = 'new-session';
      handler.resolve(
        Response(
          requestOptions: RequestOptions(
            path: 'https://shop.example/wp-json/mobishop/v1/customer/wishlist',
          ),
          data: {
            'product_ids': [1],
          },
          statusCode: 200,
        ),
      );
      await result;
      await secondResult;
      dio.close();
    },
  );
  test('another device sees saves and removals after reload', () async {
    final server = Server();
    final android = CustomerWishlistRepository(Transport(server));
    final ios = CustomerWishlistRepository(Transport(server));
    await android.updateProductIds((ids) => [2, ...ids]);
    expect(await ios.loadProductIds(), [2, 1]);
    await ios.updateProductIds((ids) => ids.where((id) => id != 1).toList());
    expect(await android.loadProductIds(), [2]);
  });
  test(
    'delta preserves a concurrent device save between read and write',
    () async {
      final server = Server();
      final transport = Transport(server)
        ..beforeMutation = () => server.ids = [3, 1];
      final repository = CustomerWishlistRepository(transport);
      expect(await repository.updateProductIds((ids) => [2, ...ids]), [
        2,
        3,
        1,
      ]);
    },
  );
  test(
    'a different customer repository cannot see previous account saves',
    () async {
      final first = CustomerWishlistRepository(Transport(Server()));
      final otherServer = Server()..ids = [];
      final other = CustomerWishlistRepository(Transport(otherServer));
      await first.updateProductIds((ids) => [9, ...ids]);
      expect(await other.loadProductIds(), isEmpty);
    },
  );
}
