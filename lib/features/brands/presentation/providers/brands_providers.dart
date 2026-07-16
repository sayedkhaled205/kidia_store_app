import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/core/network/store_api_client.dart';
import 'package:kidia_store_app/features/brands/data/datasources/brands_remote_data_source.dart';
import 'package:kidia_store_app/features/brands/data/repositories/brands_repository_impl.dart';
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
