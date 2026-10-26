import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/app_design/app_design_providers58.dart';
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
  // Validate the approved saved design before the branding error wrapper.
  // This preserves its actionable configuration error before any remote reads.
  // Startup belongs to this launch, not to a published design revision. The
  // screen providers keep watching the design; replaying startup here would
  // unmount their state whenever a new release arrives.
  ref.read(portableAppDesign58Provider);
  // The existing Retry button invalidates startup. Forward that explicit
  // action to branding too, rather than reusing its cached failed request.
  // Riverpod 3.3.2 provides this lifecycle specifically for forwarding manual
  // invalidation. Host tests cover it; review it when upgrading Riverpod.
  // ignore: experimental_member_use
  ref.onManualInvalidation(() => ref.invalidate(splashConfigProvider));
  final SplashConfig splash;
  try {
    // Cap the provider wait as well as its HTTP request. A pending/retrying
    // dependency must never leave the application on the splash indefinitely.
    splash = await ref
        .read(splashConfigProvider.future)
        .timeout(splashConfigFetchTimeout);
  } on AppConfigurationException {
    rethrow;
  } catch (error) {
    throw AppStartupBrandingException(error);
  }
  if (splash.enabled) {
    await Future<void>.delayed(splash.duration);
  }
}, retry: (retryCount, error) => null);

/// A branding-read failure, not permission to bypass store configuration,
/// customer authentication, licensing, or a commerce transport.
class AppStartupBrandingException implements Exception {
  const AppStartupBrandingException(this.cause);

  final Object cause;

  @override
  String toString() =>
      'تعذر تحميل شاشة البداية من المتجر. تأكد من اتصال الإنترنت ثم اضغط إعادة المحاولة.';
}
