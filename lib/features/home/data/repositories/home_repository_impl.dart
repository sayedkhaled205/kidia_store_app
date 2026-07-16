import 'package:dio/dio.dart';
import 'package:kidia_store_app/features/home/data/datasources/home_remote_data_source.dart';
import 'package:kidia_store_app/features/home/data/models/home_layout_model.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_layout.dart';
import 'package:kidia_store_app/features/home/domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  const HomeRepositoryImpl({
    required this._remoteDataSource,
  });

  final HomeRemoteDataSource _remoteDataSource;

  @override
  Future<HomeLayout> getHomeLayout({
    required String locale,
  }) async {
    try {
      final Map<String, dynamic> json =
      await _remoteDataSource.fetchHomeLayout(
        locale: locale,
      );

      return HomeLayoutModel.fromJson(json);
    } on DioException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        HomeRepositoryException(
          message: _resolveDioMessage(error),
          cause: error,
        ),
        stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        HomeRepositoryException(
          message: 'تعذر قراءة بيانات الصفحة الرئيسية.',
          cause: error,
        ),
        stackTrace,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        HomeRepositoryException(
          message: 'حدث خطأ غير متوقع أثناء تحميل الصفحة الرئيسية.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  String _resolveDioMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'انتهت مهلة الاتصال أثناء تحميل الصفحة الرئيسية.';

      case DioExceptionType.connectionError:
        return 'تعذر الاتصال بالخادم. تحقق من اتصال الإنترنت.';

      case DioExceptionType.badResponse:
        return _resolveBadResponseMessage(
          error.response?.statusCode,
        );

      case DioExceptionType.cancel:
        return 'تم إلغاء طلب تحميل الصفحة الرئيسية.';

      case DioExceptionType.badCertificate:
        return 'تعذر التحقق من أمان الاتصال بالخادم.';

      case DioExceptionType.unknown:
        return 'تعذر تحميل الصفحة الرئيسية حاليًا.';

      default:
        return 'تعذر تحميل الصفحة الرئيسية حاليًا.';
    }
  }

  String _resolveBadResponseMessage(int? statusCode) {
    if (statusCode == null) {
      return 'استجاب الخادم بحالة غير متوقعة.';
    }

    if (statusCode == 401 || statusCode == 403) {
      return 'غير مصرح بالوصول إلى بيانات الصفحة الرئيسية.';
    }

    if (statusCode == 404) {
      return 'لم يتم العثور على إعدادات الصفحة الرئيسية.';
    }

    if (statusCode >= 500) {
      return 'الخادم غير متاح حاليًا. حاول مرة أخرى لاحقًا.';
    }

    return 'تعذر تحميل الصفحة الرئيسية. رمز الاستجابة: $statusCode.';
  }
}

class HomeRepositoryException implements Exception {
  const HomeRepositoryException({
    required this.message,
    this.cause,
  });

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}
