import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../home/presentation/providers/home_providers.dart';
import '../domain/splash_config.dart';

final splashConfigProvider = FutureProvider<SplashConfig>((ref) async {
  if (AppConfig.useMockHomeLayout) { return const SplashConfig(duration: Duration(milliseconds: 10)); }
  final response = await ref.watch(homeDioProvider).get<dynamic>('/wp-json/woo-mobile/v1/splash-screen', options: Options(headers: const {'Cache-Control':'no-cache'}));
  final data = response.data is String ? jsonDecode(response.data as String) : response.data;
  return data is Map ? SplashConfig.fromJson(Map<String,dynamic>.from(data)) : const SplashConfig();
});
