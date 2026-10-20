import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:mobishop_store_app/features/auth/data/website_auth_service.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/website_auth_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);
  for (final platform in TargetPlatform.values) {
    test(
      '$platform consults website login only for a configured native Woo store',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        var requests = 0;
        final dio = Dio()
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (request, handler) {
                requests++;
                handler.resolve(
                  Response(
                    requestOptions: request,
                    statusCode: 200,
                    data: {'enabled': true, 'version': 1},
                  ),
                );
              },
            ),
          );
        final container = ProviderContainer(
          overrides: [
            websiteAuthServiceProvider.overrideWithValue(
              WebsiteAuthService(
                store: Uri.parse('https://store.example'),
                dio: dio,
                sessions: MemoryAuthSessionStore(),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final native =
            platform == TargetPlatform.android ||
            platform == TargetPlatform.iOS;
        final allowed =
            native &&
            AppConfig.hasConfiguredStore &&
            !AppConfig.isCmsPreview &&
            AppConfig.commercePlatform == CommercePlatform.wooCommerce;
        expect(
          await container.read(websiteAuthEnabledProvider.future),
          allowed,
        );
        expect(requests, allowed ? 1 : 0);
      },
    );
  }
}
