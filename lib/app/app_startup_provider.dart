import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../features/splash/domain/splash_config.dart';
import '../features/splash/presentation/splash_providers.dart';

final appStartupProvider = FutureProvider<void>((ref) async {
  AppConfig.validateStoreConnection();
  final SplashConfig splash = await ref.watch(splashConfigProvider.future);
  if (splash.enabled) { await Future<void>.delayed(splash.duration); }
});
