import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/wishlist/application/wishlist_repository_provider.dart';
import 'package:mobishop_store_app/features/wishlist/domain/repositories/wishlist_repository.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_wishlist_button.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_wishlist_appearance.dart';

class _SignedOut extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}
class _Repository implements WishlistRepository {
  List<int> ids = [8];
  bool fail = false;
  @override
  Future<List<int>> loadProductIds() async => List.of(ids);
  @override
  Future<void> saveProductIds(List<int> values) async {
    if (fail) throw StateError('storage unavailable');
    ids = List.of(values);
  }
}
Widget _app(_Repository repository) => ProviderScope(overrides: [
  wishlistRepositoryProvider.overrideWithValue(repository),
  authControllerProvider.overrideWith(_SignedOut.new),
  cmsPageLayoutProvider('wishlist').overrideWithValue(AsyncData(CmsPageLayout.fromJson({
    'page': 'wishlist', 'settings': {'wishlist_access_mode': 'guest'},
  }))),
], child: const MaterialApp(home: Scaffold(body: Row(children: [
  ProductWishlistButton(productId: 1, appearance: ProductWishlistAppearance(enabled: true)),
  ProductWishlistButton(productId: 2, appearance: ProductWishlistAppearance(enabled: true)),
]))));
void main() {
  testWidgets('two product hearts share the mutation queue and observe removals', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    tester.widget<IconButton>(find.byKey(const Key('product-card-wishlist-1'))).onPressed!();
    tester.widget<IconButton>(find.byKey(const Key('product-card-wishlist-2'))).onPressed!();
    await tester.pumpAndSettle();
    expect(repository.ids, [2, 1, 8]);
    expect(find.byIcon(Icons.favorite_rounded), findsNWidgets(2));
    await repository.updateProductIds((ids) => ids.where((id) => id != 1).toList());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
  });
  testWidgets('failed save preserves heart state and a later retry succeeds', (tester) async {
    final repository = _Repository()..fail = true;
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('product-card-wishlist-1')));
    await tester.pumpAndSettle();
    expect(repository.ids, [8]);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
    expect(find.text('Unable to save your wishlist. Please try again.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    repository.fail = false;
    await tester.tap(find.byKey(const Key('product-card-wishlist-1')));
    await tester.pumpAndSettle();
    expect(repository.ids, [1, 8]);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });
}
