import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/brands/data/datasources/brands_remote_data_source.dart';
import 'package:kidia_store_app/features/brands/domain/entities/store_brand.dart';
import 'package:kidia_store_app/features/brands/domain/repositories/brands_repository.dart';

class BrandsRepositoryImpl implements BrandsRepository {
  const BrandsRepositoryImpl(this._remoteDataSource);

  final BrandsRemoteDataSource _remoteDataSource;

  @override
  Future<StoreBrandPage> getBrands({
    required int page,
    required int perPage,
    required String search,
  }) async {
    try {
      return await _remoteDataSource.fetchBrands(
        page: page,
        perPage: perPage,
        search: search,
      );
    } on StoreApiException catch (error, stackTrace) {
      if (error.kind == StoreApiFailureKind.notFound ||
          error.statusCode == 404 ||
          error.statusCode == 501) {
        Error.throwWithStackTrace(
          const BrandsUnsupportedException(),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(
        BrandsRepositoryException(
          kind: error.kind,
          message: error.message,
          statusCode: error.statusCode,
          cause: error,
        ),
        stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        BrandsRepositoryException(
          kind: StoreApiFailureKind.invalidResponse,
          message: 'The store returned invalid brands data.',
          cause: error,
        ),
        stackTrace,
      );
    } on BrandsUnsupportedException {
      rethrow;
    } on BrandsRepositoryException {
      rethrow;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        BrandsRepositoryException(
          kind: StoreApiFailureKind.unknown,
          message: 'The brands request failed unexpectedly.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }
}
