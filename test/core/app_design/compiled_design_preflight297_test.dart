import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/app_design_bundle58.dart';
import 'package:mobishop_store_app/core/app_design/app_design_providers58.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/home/data/models/home_layout_model.dart';

// CI supplies the exact --dart-define-from-file and STORE_* values used by the
// native compiler. This runs the authoritative Dart renderer schema, rather
// than merely checking that the public Base64 transport is well formed.
void main() {
  test(
    'the actual compiled saved design passes the native startup boundary',
    () {
      const required = bool.fromEnvironment('REQUIRE_SAVED_DESIGN');
      if (AppConfig.appDesignBundle.isEmpty && !required) {
        expect(AppConfig.commercePlatform, CommercePlatform.wooCommerce);
        return; // Explicit legacy Woo builds can still use their live CMS.
      }
      expect(AppConfig.isCmsPreview, isFalse);
      expect(AppConfig.appDesignBundle, isNotEmpty);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final design = container.read(portableAppDesign58Provider);
      expect(design, isNotNull);
      expect(design!.platform, AppConfig.commercePlatform);
      expect(design.storeOrigin, AppConfig.commerceConnection.storeOrigin);
      final homeJson = Map<String, dynamic>.from(
        design.toJson()['home'] as Map,
      );
      final home = HomeLayoutModel.fromJson(homeJson);
      expect(home.locale, AppConfig.storeLocale);
      expect(home.blocks.length, (homeJson['blocks'] as List).length);
      expect(design.identity, isNotEmpty);
      expect(design.splash.duration.inMilliseconds, isNonNegative);
      for (final page in AppDesignBundle58.pages) {
        expect(design.pageLayout(page).page, page);
      }
    },
  );
}
