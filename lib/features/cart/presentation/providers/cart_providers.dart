import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/core/network/store_api_client.dart';
import 'package:kidia_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kidia_store_app/features/cart/data/datasources/cart_remote_data_source.dart';
import 'package:kidia_store_app/features/cart/data/network/cart_api_transport.dart';
import 'package:kidia_store_app/features/cart/data/network/cart_token_store.dart';
import 'package:kidia_store_app/features/cart/data/repositories/cart_repository_impl.dart';
import 'package:kidia_store_app/features/cart/domain/repositories/cart_repository.dart';

/// One configured Dio client is shared by the Store API bootstrap request and
/// token-authenticated cart requests for the lifetime of the provider scope.
final cartDioProvider = Provider<Dio>((Ref ref) {
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
    ),
  );
  ref.onDispose(dio.close);
  return dio;
});

final cartStoreApiClientProvider = Provider<StoreApiClient>((Ref ref) {
  return DioStoreApiClient.forConfiguredStore(dio: ref.watch(cartDioProvider));
});

final cartApiTransportProvider = Provider<CartApiTransport>((Ref ref) {
  return StoreApiCartTransport.forConfiguredStore(
    dio: ref.watch(cartDioProvider),
    authTokenReader: () =>
        ref.read(authControllerProvider).asData?.value?.token,
  );
});

final cartTokenStoreProvider = Provider<CartTokenStore>((Ref ref) {
  return MemoryCartTokenStore();
});

final cartRemoteDataSourceProvider = Provider<CartRemoteDataSource>((Ref ref) {
  return StoreApiCartRemoteDataSource(
    storeApiClient: ref.watch(cartStoreApiClientProvider),
    transport: ref.watch(cartApiTransportProvider),
    tokenStore: ref.watch(cartTokenStoreProvider),
  );
});

final cartRepositoryProvider = Provider<CartRepository>((Ref ref) {
  return CartRepositoryImpl(ref.watch(cartRemoteDataSourceProvider));
});
