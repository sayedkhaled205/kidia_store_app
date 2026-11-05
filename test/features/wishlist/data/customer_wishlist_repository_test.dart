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

void main() {
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
      final pending = transport.fetchWishlist();
      final result = expectLater(
        pending,
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
