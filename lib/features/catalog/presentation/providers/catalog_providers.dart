import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/core/network/store_api_client.dart';
import 'package:kidia_store_app/features/catalog/data/datasources/catalog_remote_data_source.dart';
import 'package:kidia_store_app/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';

/// The catalog's transport boundary.
///
/// Tests and store-specific shells can override this provider without replacing
/// any presentation code. No WooCommerce credentials are embedded in the app:
/// the public Store API is always scoped to [AppConfig.apiBaseUrl].
final catalogStoreApiClientProvider = Provider<StoreApiClient>((Ref ref) {
  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
    ),
  );
  ref.onDispose(dio.close);

  return DioStoreApiClient.forConfiguredStore(dio: dio);
});

final catalogRemoteDataSourceProvider = Provider<CatalogRemoteDataSource>(
  (Ref ref) =>
      StoreApiCatalogRemoteDataSource(ref.watch(catalogStoreApiClientProvider)),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (Ref ref) =>
      CatalogRepositoryImpl(ref.watch(catalogRemoteDataSourceProvider)),
);
