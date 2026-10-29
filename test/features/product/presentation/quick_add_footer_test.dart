import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/app_ui_controls.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/product/presentation/widgets/product_quick_add.dart';
import 'package:mobishop_store_app/features/wishlist/application/wishlist_access_provider.dart';
import 'package:mobishop_store_app/features/wishlist/application/wishlist_repository_provider.dart';
import 'package:mobishop_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';

class _Repository implements WishlistRepository {
  List<int> ids = [];
  @override
  Future<List<int>> loadProductIds() async => List.of(ids);
  @override
  Future<void> saveProductIds(List<int> values) async {
    ids = List.of(values);
  }
}

void main() {
  for (final (language, custom) in [
    ('ar', false),
    ('en', false),
    ('ar', true),
    ('en', true),
  ]) {
    testWidgets(
      'quick add footer preserves wishlist and cart actions in $language, published=$custom',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository();
        var additions = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              wishlistRepositoryProvider.overrideWithValue(repository),
              wishlistAccessProvider.overrideWithValue(
                const WishlistAccess(requiresSignIn: false),
              ),
            ],
            child: MaterialApp(
              builder: (context, child) => AppUiControlsScope(
                controls: AppUiControls.fromJson(
                  custom
                      ? {
                          'quickadd_side_padding': 24,
                          'quickadd_vertical_padding': 16,
                          'quickadd_gap': 20,
                          'quickadd_wishlist_width': 80,
                          'quickadd_wishlist_icon_size': 30,
                          'quickadd_button_height': 60,
                          'quickadd_button_radius': 18,
                          'quickadd_button_font_size': 20,
                        }
                      : {},
                ),
                child: child!,
              ),
              locale: Locale(language),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 700),
                  padding: EdgeInsets.only(bottom: 24),
                  viewPadding: EdgeInsets.only(bottom: 24),
                  textScaler: TextScaler.linear(1.5),
                ),
                child: Scaffold(
                  bottomNavigationBar: SafeArea(
                    top: false,
                    child: ProductQuickAddFooter(
                      productId: 42,
                      settings: const CmsPageComponent(
                        id: 'footer',
                        type: 'footer',
                        enabled: true,
                        settings: {
                          'button_color': '#4EA999',
                          'button_text_color': '#FFFFFF',
                          'button_height': 50,
                        },
                      ),
                      onAdd: () => additions++,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final add = find.byKey(const Key('product-quick-add-submit'));
        expect(
          find.text(language == 'ar' ? 'أضف إلى السلة' : 'Add to cart'),
          findsOneWidget,
        );
        expect(tester.getBottomLeft(add).dy, lessThanOrEqualTo(676));
        expect(
          tester.widget<FilledButton>(add).style!.shape!.resolve({}),
          custom ? isA<RoundedRectangleBorder>() : isA<StadiumBorder>(),
        );
        await tester.tap(find.byKey(const Key('product-card-wishlist-42')));
        await tester.pumpAndSettle();
        expect(repository.ids, [42]);
        await tester.tap(add);
        expect(additions, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
