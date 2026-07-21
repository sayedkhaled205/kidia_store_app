import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../features/splash/domain/splash_config.dart';
import '../features/splash/presentation/splash_providers.dart';

final appStartupProvider = FutureProvider<void>((ref) async {
  // The embedded CMS preview receives its layout from the parent frame. It
  // must render immediately instead of waiting for a store API request that
  // can be blocked by admin authentication, CORS, or a slow endpoint.
  if (AppConfig.isCmsPreview) {
    return;
  }
  AppConfig.validateStoreConnection();
  final SplashConfig splash = await ref.watch(splashConfigProvider.future);
  if (splash.enabled) { await Future<void>.delayed(splash.duration); }
});
