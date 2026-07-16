import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/core/network/store_api_client.dart';
import 'package:kidia_store_app/features/brands/data/datasources/brands_remote_data_source.dart';
import 'package:kidia_store_app/features/brands/data/repositories/brands_repository_impl.dart';
import 'package:kidia_store_app/features/brands/domain/entities/store_brand.dart';
import 'package:kidia_store_app/features/brands/domain/repositories/brands_repository.dart';
import 'package:kidia_store_app/features/brands/presentation/controllers/brands_controller.dart';

final brandsStoreApiClientProvider = Provider<StoreApiClient>((Ref ref) {
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

final brandsRemoteDataSourceProvider = Provider<BrandsRemoteDataSource>(
  (Ref ref) =>
      StoreApiBrandsRemoteDataSource(ref.watch(brandsStoreApiClientProvider)),
);

final brandsRepositoryProvider = Provider<BrandsRepository>(
  (Ref ref) => BrandsRepositoryImpl(ref.watch(brandsRemoteDataSourceProvider)),
);

final brandsControllerProvider = Provider.autoDispose<BrandsController>((
  Ref ref,
) {
  final BrandsController controller = BrandsController(
    ref.watch(brandsRepositoryProvider),
  );
  ref.onDispose(controller.dispose);
  unawaited(controller.loadInitial());
  return controller;
});

/// Loads the complete brand list used by catalog filters.
///
/// WooCommerce caps one response at 100 terms, so larger stores are fetched
/// page by page. Unsupported stores simply expose no brand selector while the
/// rest of the catalog remains usable.
final catalogFilterBrandsProvider = FutureProvider<List<StoreBrand>>((
  Ref ref,
) async {
  final BrandsRepository repository = ref.watch(brandsRepositoryProvider);
  final Map<int, StoreBrand> brands = <int, StoreBrand>{};
  int page = 1;
  int totalPages = 1;

  try {
    do {
      final StoreBrandPage result = await repository.getBrands(
        page: page,
        perPage: 100,
        search: '',
      );
      for (final StoreBrand brand in result.items) {
        brands[brand.id] = brand;
      }
      totalPages = result.totalPages < 1 ? 1 : result.totalPages;
      page++;
    } while (page <= totalPages);
  } on BrandsUnsupportedException {
    return const <StoreBrand>[];
  }

  final List<StoreBrand> result = brands.values.toList()
    ..sort(
      (StoreBrand first, StoreBrand second) =>
          first.name.toLowerCase().compareTo(second.name.toLowerCase()),
    );
  return List<StoreBrand>.unmodifiable(result);
});
