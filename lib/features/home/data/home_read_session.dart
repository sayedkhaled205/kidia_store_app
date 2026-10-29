import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:dio/dio.dart';
import 'package:mobishop_store_app/core/network/store_api_exception.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/home/data/repositories/home_repository_impl.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_layout.dart';

/// Public home content only. Never used to approve purchases or cart changes.
class HomeReadSession {
  final _saved = <String, (HomeLayout, DateTime)>{};
  final _stale = <String>{};
  bool isStale(String locale) => _stale.contains(locale);

  Future<HomeLayout> load(
    String locale,
    Future<HomeLayout> Function() read, {
    Future<void> Function()? pause,
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        final layout = await read();
        if (layout.blocks.any((block) => block is CatalogUnavailableBlock)) {
          _stale.add(locale);
          final previous = _saved[locale];
          if (previous != null &&
              DateTime.now().difference(previous.$2) <
                  const Duration(days: 7)) {
            return previous.$1;
          }
          return layout;
        }
        _saved[locale] = (layout, DateTime.now());
        _stale.remove(locale);
        return layout;
      } catch (error) {
        if (!isTransient(error)) {
          _saved.remove(locale);
          _stale.remove(locale);
          rethrow;
        }
        if (attempt == 0) {
          await (pause?.call() ??
              Future<void>.delayed(const Duration(milliseconds: 650)));
          continue;
        }
        final previous = _saved[locale];
        if (previous != null &&
            DateTime.now().difference(previous.$2) < const Duration(days: 7)) {
          _stale.add(locale);
          return previous.$1;
        }
        rethrow;
      }
    }
  }

  static bool isTransient(Object error) {
    if (error is HomeRepositoryException && error.cause != null) {
      return isTransient(error.cause!);
    }
    if (error is CatalogRepositoryException) {
      return {
        StoreApiFailureKind.connection,
        StoreApiFailureKind.timeout,
        StoreApiFailureKind.server,
      }.contains(error.kind);
    }
    if (error is DioException) {
      return {
            DioExceptionType.connectionError,
            DioExceptionType.connectionTimeout,
            DioExceptionType.sendTimeout,
            DioExceptionType.receiveTimeout,
          }.contains(error.type) ||
          (error.type == DioExceptionType.badResponse &&
              (error.response?.statusCode ?? 0) >= 500);
    }
    return false;
  }
}
