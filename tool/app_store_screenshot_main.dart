// Simulator-only listing capture. The shipping entry point remains lib/main.dart.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/app/app.dart';
import 'package:mobishop_store_app/app/app_router.dart';
import 'package:mobishop_store_app/core/localization/app_locale_provider.dart';

Future<void> main() async {
  if (!kDebugMode || defaultTargetPlatform != TargetPlatform.iOS) {
    throw UnsupportedError('Listing capture requires an iOS debug simulator.');
  }
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  await container.read(appLanguagePreferenceProvider.future);
  await container
      .read(appLanguagePreferenceProvider.notifier)
      .select(AppLanguage.ar);
  final view = binding.platformDispatcher.views.first;
  final width = view.physicalSize.width / view.devicePixelRatio;
  final router = createAppRouter(
    initialLocation: width >= 600 ? '/categories' : '/',
  );
  // Use the actual screens, saved design and live catalog. Push enrollment is
  // intentionally not started in this capture entry point, so its first-run
  // system prompt cannot obscure the listing image. No product data is mocked.
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MobiShopApp(router: router),
    ),
  );
}
