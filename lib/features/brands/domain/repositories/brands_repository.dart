import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/brands/domain/entities/store_brand.dart';

abstract interface class BrandsRepository {
  Future<StoreBrandPage> getBrands({
    required int page,
    required int perPage,
    required String search,
  });
}

class BrandsUnsupportedException implements Exception {
  const BrandsUnsupportedException();
}

class BrandsRepositoryException implements Exception {
  const BrandsRepositoryException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.cause,
  });

  final StoreApiFailureKind kind;
  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}
