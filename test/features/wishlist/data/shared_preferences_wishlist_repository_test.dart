import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/wishlist/data/shared_preferences_wishlist_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('stores normalized ids separately for each WooCommerce store', () async {
    final SharedPreferencesWishlistRepository firstStore =
        SharedPreferencesWishlistRepository(
          storeUrl: 'https://first.example.com',
        );
    final SharedPreferencesWishlistRepository secondStore =
        SharedPreferencesWishlistRepository(
          storeUrl: 'https://second.example.com',
        );

    await firstStore.saveProductIds(<int>[3, 2, 3, -1, 0]);

    expect(await firstStore.loadProductIds(), <int>[3, 2]);
    expect(await secondStore.loadProductIds(), isEmpty);
    expect(firstStore.storageKey, isNot(secondStore.storageKey));
  });

  test('canonicalizes the same store origin to one stable scope', () {
    final SharedPreferencesWishlistRepository first =
        SharedPreferencesWishlistRepository(
          storeUrl: 'HTTPS://Shop.Example.com:443/',
        );
    final SharedPreferencesWishlistRepository second =
        SharedPreferencesWishlistRepository(
          storeUrl: 'https://shop.example.com',
        );
    final SharedPreferencesWishlistRepository subdirectory =
        SharedPreferencesWishlistRepository(
          storeUrl: 'https://shop.example.com/outlet',
        );

    expect(first.storageKey, second.storageKey);
    expect(first.storageKey, isNot(subdirectory.storageKey));
  });

  test('filters and repairs corrupted local values', () async {
    final SharedPreferencesWishlistRepository repository =
        SharedPreferencesWishlistRepository(
          storeUrl: 'https://shop.example.com',
        );
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(repository.storageKey, <String>[
      ' 4 ',
      'bad',
      '-1',
      '4',
      '5',
    ]);

    expect(await repository.loadProductIds(), <int>[4, 5]);
    expect(preferences.getStringList(repository.storageKey), <String>[
      '4',
      '5',
    ]);
  });
}
