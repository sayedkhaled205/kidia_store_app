import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/app_design/app_design_bundle58.dart';
import 'package:mobishop_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';

void main() {
  test(
    'the exact current native build design loads its live Woo Home sections',
    () async {
      final previous = HttpOverrides.current;
      HttpOverrides.global = null;
      final container = ProviderContainer();
      try {
        expect(AppConfig.apiBaseUrl, 'https://staging.kidiastore.com');
        final design = AppDesignBundle58.fromEncoded(
          (jsonDecode(
                    File(
                      Platform.environment['WOOMOBILE_HOME_TEST_DESIGN']!,
                    ).readAsStringSync(),
                  )
                  as Map<String, dynamic>)['APP_DESIGN_BUNDLE']
              as String,
          platform: AppConfig.commercePlatform,
          storeOrigin: Uri.parse(AppConfig.apiBaseUrl),
        );
        final home = await design.hydrateHome(
          container.read(catalogRepositoryProvider),
          locale: 'ar',
        );
        expect(home.blocks.length, 7);
        expect(home.blocks.whereType<CatalogUnavailableBlock>(), isEmpty);
        final products =
            home.blocks.whereType<ProductCarouselBlock>().fold<int>(
              0,
              (n, b) => n + b.items.length,
            ) +
            home.blocks.whereType<ProductGridBlock>().fold<int>(
              0,
              (n, b) => n + b.items.length,
            );
        final categories = home.blocks.whereType<CategoryGridBlock>().fold<int>(
          0,
          (n, b) => n + b.items.length,
        );
        expect(products, greaterThan(0));
        expect(categories, greaterThan(0));
        print(
          'LIVE_HOME_VERIFIED blocks=${home.blocks.length} products=$products categories=$categories',
        );
      } finally {
        container.dispose();
        HttpOverrides.global = previous;
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
