import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/features/home/data/datasources/home_remote_data_source.dart';
import 'package:kidia_store_app/features/home/data/repositories/home_repository_impl.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_layout.dart';
import 'package:kidia_store_app/features/home/domain/repositories/home_repository.dart';

final homeDioProvider = Provider<Dio>((Ref ref) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 25),
      responseType: ResponseType.json,
      headers: const <String, dynamic>{
        'Accept': 'application/json',
      },
    ),
  );

  ref.onDispose(dio.close);

  return dio;
});

final homeRemoteDataSourceProvider =
Provider<HomeRemoteDataSource>((Ref ref) {
  if (AppConfig.useMockHomeLayout) {
    return const MockHomeRemoteDataSource();
  }

  return DioHomeRemoteDataSource(
    dio: ref.watch(homeDioProvider),
    endpoint: AppConfig.homeLayoutEndpoint,
  );
});

final homeRepositoryProvider = Provider<HomeRepository>((Ref ref) {
  return HomeRepositoryImpl(
    remoteDataSource: ref.watch(homeRemoteDataSourceProvider),
  );
});

final homeLayoutProvider =
FutureProvider.autoDispose.family<HomeLayout, String>(
      (Ref ref, String locale) async {
    final HomeRepository repository = ref.watch(
      homeRepositoryProvider,
    );

    return repository.getHomeLayout(
      locale: locale,
    );
  },
);