import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_money.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/presentation/widgets/catalog_product_card.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:mobishop_store_app/features/home/presentation/widgets/home_block_widgets.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/features/wishlist/application/wishlist_repository_provider.dart';
import 'package:mobishop_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:mobishop_store_app/shared/widgets/product/store_product_card.dart';
import 'package:mobishop_store_app/shared/widgets/product/store_product_card_data.dart';
import 'package:mobishop_store_app/features/wishlist/presentation/wishlist_screen.dart';
import '../../features/wishlist/support/wishlist_test_data.dart' as fixtures;

class _SignedOut extends AuthController {
  @override Future<AuthSession?> build() async => null;
}
class _Wishlist implements WishlistRepository {
  List<int> ids = [];
  @override Future<List<int>> loadProductIds() async => List.of(ids);
  @override Future<void> saveProductIds(List<int> value) async { ids = List.of(value); }
}
const product = CatalogProduct(id: 14, name: 'Kids outfit', slug: 'outfit', type: 'simple',
  isInStock: true, isPurchasable: true, prices: CatalogMoney(currencyCode: 'EGP',
    currencySymbol: 'EGP', currencyMinorUnit: 2, priceMinor: '108500'));
const homeProduct = HomeProductItem(id: 14, name: 'Kids outfit', imageUrl: '', price: '1085',
  regularPrice: null, currencyCode: 'EGP', currencySymbol: 'EGP', inStock: true,
  badge: null, rating: 0, reviewCount: 0, discountPercent: 0,
  action: HomeAction(type: 'product', value: '14'));
const style = <String, dynamic>{'share_style_across_app': true, 'card_style': 'outlined',
  'card_outline_color': '#A1CCC4', 'card_outline_width': .75, 'card_radius': 8,
  'image_inset': 0, 'image_radius': 0, 'image_ratio': .9, 'show_name': false,
  'show_price': true, 'show_badge': false, 'show_rating': false,
  'price_size': 16, 'price_color': '#4EA999', 'content_horizontal_padding': 12,
  'content_top_padding': 10, 'content_bottom_padding': 12,
  'show_wishlist': true, 'quick_add_enabled': true, 'enable_image_swipe': true};
CmsPageLayout catalog(Map<String,dynamic> settings) => CmsPageLayout.fromJson({
  'page':'catalog','elements':[{'id':'product_grid','type':'product_grid','enabled':true,'settings':settings}]});

void main() {
  testWidgets('saved wishlist and recommendations share the renderer without losing removal', (tester) async {
    final repository = fixtures.FakeWishlistRepository(ids:[1]);
    await tester.pumpWidget(ProviderScope(overrides: [
      cmsPageLayoutProvider('catalog').overrideWithValue(AsyncData(catalog(style))),
      wishlistRepositoryProvider.overrideWithValue(repository),
      authControllerProvider.overrideWith(_SignedOut.new),
    ], child: MaterialApp(home: WishlistScreen(repository: repository,
      catalogRepository: fixtures.FakeWishlistCatalogRepository(
        onGetProducts: (_) async => fixtures.catalogPage([fixtures.wishlistProductOne]))))));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wishlist-product-1')), findsOneWidget);
    final saved = tester.widget<StoreProductCard>(find.byType(StoreProductCard).first);
    expect(saved.settings!.number('card_outline_width',0), .75);
    await tester.tap(find.byKey(const Key('wishlist-remove-1')));
    await tester.pumpAndSettle();
    expect(repository.ids, isEmpty);
    expect(find.byKey(const Key('wishlist-empty')), findsOneWidget);
    expect(find.byType(StoreProductCard), findsWidgets);
    for (final card in tester.widgetList<StoreProductCard>(find.byType(StoreProductCard))) {
      expect(card.settings!.string('price_color',''), '#4EA999');
      expect(card.fitImageRatio, isTrue);
    }
    expect(tester.takeException(), isNull);
  });
  test('both sources format the same price without precision loss', () {
    expect(StoreProductCardData.catalog(product, shared: true).currentPrice,
      StoreProductCardData.home(homeProduct).currentPrice);
    expect(StoreProductCardData.priceText('9007199254740993.2500', 'EGP'), '9007199254740993.25 EGP');
    expect(StoreProductCardData.priceText('', 'EGP'), '');
    expect(StoreProductCardData.priceText('1.005', 'KWD'), '1.005 KWD');
  });
  for (final locale in ['en','ar']) {
    testWidgets('shared home and catalog card geometry, actions and live style in $locale', (tester) async {
      final wishlist = _Wishlist();
      var taps = 0;
      Future<void> pump(Map<String,dynamic> settings) async {
        await tester.pumpWidget(ProviderScope(overrides: [
          cmsPageLayoutProvider('catalog').overrideWithValue(AsyncData(catalog(settings))),
          cmsPageLayoutProvider('wishlist').overrideWithValue(AsyncData(CmsPageLayout.fromJson({
            'page':'wishlist','settings':{'wishlist_access_mode':'guest'}}))),
          wishlistRepositoryProvider.overrideWithValue(wishlist),
          authControllerProvider.overrideWith(_SignedOut.new),
        ], child: MaterialApp(locale: Locale(locale), supportedLocales: const [Locale('en'),Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.8)), child: child!),
          home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 320, child: Column(children: [
            SizedBox(width: 144, child: CatalogProductCard(product: product, fitImageRatio: true,
              settings: const CmsPageComponent(id:'grid',type:'product_grid',enabled:true,
                settings:{'card_outline_color':'#FF0000','price_color':'#000000'}), onTap: () => taps++)),
            ProductGridBlockWidget(block: const ProductGridBlock(id:'home', enabled:true, items:[homeProduct,homeProduct],
              title: null, subtitle: null, columns: 2, showViewAll: false, viewAllLabel: null,
              viewAllAction: null, cardStyle: 'minimal', imageRatio: 1, cardRadius: 0,
              showName: true, showPrice: true, showRegularPrice: true, showBadge: true,
              showRating: true, quickAddEnabled: false),
              onAction: (_) => taps++),
          ])))))));
        await tester.pumpAndSettle();
      }
      await pump(style);
      expect(tester.takeException(), isNull);
      expect(find.byType(StoreProductCard), findsNWidgets(3));
      expect(find.text('1085 EGP'), findsNWidgets(3));
      for (final card in tester.widgetList<StoreProductCard>(find.byType(StoreProductCard))) {
        expect(card.settings!.string('card_outline_color',''), '#A1CCC4');
        expect(card.settings!.number('card_outline_width',0), .75);
        expect(card.settings!.string('price_color',''), '#4EA999');
      }
      await tester.tap(find.text('1085 EGP').first);
      expect(taps, 1);
      await tester.tap(find.byKey(const Key('product-card-wishlist-14')).first);
      await tester.pumpAndSettle();
      expect(wishlist.ids, [14]);
      await pump({...style, 'card_outline_width': 1.25, 'price_color':'#123456'});
      for (final card in tester.widgetList<StoreProductCard>(find.byType(StoreProductCard))) {
        expect(card.settings!.number('card_outline_width',0), 1.25);
        expect(card.settings!.string('price_color',''), '#123456');
      }
      expect(tester.takeException(), isNull);
    });
  }
}
