import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/app_design/app_design_providers58.dart';
import '../../../core/commerce/commerce_connection.dart';
import '../../home/presentation/providers/home_providers.dart';
import '../domain/splash_config.dart';

const splashConfigFetchTimeout = Duration(seconds: 10);

final splashConfigProvider = FutureProvider<SplashConfig>((ref) async {
  // The splash can also be read directly by the loading screen. Validate that
  // path before creating any transport, just as application startup does.
  AppConfig.validateStoreConnection();
  if (!AppConfig.isCmsPreview &&
      AppConfig.commercePlatform != CommercePlatform.wooCommerce) {
    return ref.watch(portableAppDesign58Provider)!.splash;
  }
  if (AppConfig.useMockHomeLayout) {
    return const SplashConfig(duration: Duration(milliseconds: 10));
  }
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final response = await ref
      .watch(homeDioProvider)
      .get<dynamic>(
        '/wp-json/mobishop/v1/splash-screen',
        cancelToken: cancelToken,
        options: Options(headers: const {'Cache-Control': 'no-cache'}),
      )
      .timeout(
        splashConfigFetchTimeout,
        onTimeout: () {
          cancelToken.cancel();
          throw TimeoutException('Splash branding request timed out.');
        },
      );
  final data = response.data is String
      ? jsonDecode(response.data as String)
      : response.data;
  return data is Map
      ? SplashConfig.fromJson(Map<String, dynamic>.from(data))
      : const SplashConfig();
}, retry: (retryCount, error) => null);
