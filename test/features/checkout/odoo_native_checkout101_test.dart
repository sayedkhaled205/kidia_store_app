import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/app/app_router.dart';
import 'package:mobishop_store_app/app/hosted_commerce_screen297.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/odoo_customer_providers51.dart';
import 'package:mobishop_store_app/features/cart/data/odoo/odoo_cart85.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:mobishop_store_app/features/checkout/data/odoo/odoo_checkout101.dart';
import 'package:mobishop_store_app/features/checkout/presentation/odoo_checkout_screen101.dart';
import '../../core/commerce/support/odoo_merchant100.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_variation.dart';
import 'package:mobishop_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mobishop_store_app/features/cart/presentation/adapters/product_purchase_selection.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/compact_family_provider.dart';
import '../product/support/product_test_data.dart';

class CheckoutFixture101 implements OdooCheckoutApi101 {
  final merchant = OdooMerchant100('alpha.odoo.example.invalid')..quantity = 1;
  final saves = <Map<String, String>>[];
  final requests = <(int, String)>[];
  bool separate = false, failSelection = false, failForm = false;
  bool sameAddress = true;
  Completer<OdooAddressForm101>? pendingForm;
  final types = <String>[];
  OdooCart85 cart({bool selected = false}) {
    final raw = merchant.cart;
    (raw['totals'] as Map)['total_minor'] = selected ? '15013' : '13579';
    return OdooCart85.fromResponse(
      {'cart_contract_version': '85.1', 'customer_id': null, 'cart': raw},
      customerId: null,
      origin: Uri.https(merchant.host),
    );
  }

  OdooAddressForm101 address({String type = 'billing', int country = 1}) =>
      OdooAddressForm101.fromResponse({
        'checkout_form_contract_version': '101.1',
        'address_type': type,
        'separate_shipping_allowed': separate,
        'use_same_address': sameAddress,
        'fields': [
          {
            'name': 'name',
            'label': 'Merchant customer name',
            'kind': 'text',
            'value': '',
            'required': true,
            'readonly': false,
            'choices': [],
          },
          {
            'name': 'country_id',
            'label': 'Country',
            'kind': 'select',
            'value': '$country',
            'required': true,
            'readonly': false,
            'choices': [
              {'value': '1', 'label': 'Egypt'},
              {'value': '2', 'label': 'United States'},
            ],
          },
          {
            'name': 'state_id',
            'label': country == 1 ? 'المحافظة' : 'State',
            'kind': 'select',
            'value': '',
            'required': true,
            'readonly': false,
            'choices': [
              {
                'value': country == 1 ? '10' : '20',
                'label': country == 1 ? 'Cairo' : 'New York',
              },
            ],
          },
        ],
      }, cart());
  OdooShipping101 shipping({bool selected = false}) =>
      OdooShipping101.fromResponse({
        'shipping_contract_version': '100.1',
        'shipping_rates': [
          {
            'carrier_id': 8,
            'name': 'Merchant delivery',
            'display_price_minor': '1434',
            'price_minor': '1258',
            'tax_minor': '176',
            'selected': selected,
            'estimated': false,
          },
        ],
      }, cart(selected: selected));
  @override
  Future<OdooAddressForm101> form({
    String type = 'billing',
    int? countryId,
  }) async {
    types.add(type);
    if (failForm) throw StateError('Merchant metadata unavailable');
    return pendingForm?.future ?? address(type: type, country: countryId ?? 1);
  }

  @override
  Future<OdooShipping101> save({
    required String type,
    required Map<String, String> fields,
    required bool useForShipping,
  }) async {
    saves.add(fields);
    return shipping();
  }

  @override
  Future<OdooShipping101> quote() async => shipping();
  @override
  Future<OdooShipping101> select(int id, String revision) async {
    requests.add((id, revision));
    if (failSelection) throw StateError('Stale revision');
    return shipping(selected: true);
  }
}

Future<void> open(WidgetTester tester, CheckoutFixture101 api) async {
  await tester.pumpWidget(MaterialApp(home: OdooCheckoutForm101(api: api)));
  await tester.pumpAndSettle();
}

Future<void> fill(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextFormField).first,
    'Native checkout buyer',
  );
  await tester.tap(find.byType(DropdownButtonFormField<String>).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cairo').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('existing separate delivery choice survives reopening checkout', (
    tester,
  ) async {
    final api = CheckoutFixture101()
      ..separate = true
      ..sameAddress = false;
    await open(tester, api);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    await fill(tester);
    await tester.ensureVisible(find.text('Save and continue'));
    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();
    expect(api.types, ['billing', 'delivery']);
  });
  testWidgets(
    'merchant fields, required validation and separate-address setting are native',
    (tester) async {
      final api = CheckoutFixture101();
      await open(tester, api);
      expect(find.text('المحافظة'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsNothing);
      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();
      expect(api.saves, isEmpty);
      expect(find.text('This field is required'), findsNWidgets(2));
      await fill(tester);
      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();
      expect(api.saves.single, {
        'name': 'Native checkout buyer',
        'country_id': '1',
        'state_id': '10',
      });
      expect(find.text('Merchant delivery'), findsOneWidget);
      expect(find.textContaining('No order has been placed'), findsOneWidget);
    },
  );
  testWidgets(
    'changing country refreshes merchant choices while preserving typed name',
    (tester) async {
      final api = CheckoutFixture101();
      await open(tester, api);
      await fill(tester);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('United States').last);
      await tester.pumpAndSettle();
      expect(find.text('Native checkout buyer'), findsOneWidget);
      expect(find.text('Cairo'), findsNothing);
      expect(find.text('State'), findsOneWidget);
      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();
      expect(
        api.saves,
        isEmpty,
        reason: 'Old governorate must not survive country change',
      );
    },
  );
  testWidgets(
    'rejected country restores visible country and preserves the previous draft',
    (tester) async {
      final api = CheckoutFixture101();
      await open(tester, api);
      await fill(tester);
      api.failForm = true;
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('United States').last);
      await tester.pumpAndSettle();
      final country = tester.state<FormFieldState<String>>(
        find.byType(DropdownButtonFormField<String>).first,
      );
      expect(country.value, '1');
      expect(find.text('Native checkout buyer'), findsOneWidget);
      expect(find.text('Cairo'), findsOneWidget);
      expect(find.textContaining('Unable to update checkout'), findsOneWidget);
      expect(api.saves, isEmpty);
    },
  );
  testWidgets(
    'shipping selection uses quote revision and refreshes exact total',
    (tester) async {
      final api = CheckoutFixture101();
      await open(tester, api);
      await fill(tester);
      await tester.tap(find.text('Save and continue'));
      await tester.pumpAndSettle();
      expect(find.text('EGP 135.79'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('carrier-8')));
      await tester.pumpAndSettle();
      expect(api.requests.single, (8, 'a' * 64));
      expect(find.text('EGP 150.13'), findsOneWidget);
      api.failSelection = true;
      await tester.tap(find.byKey(const ValueKey('carrier-8')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkout-total')), findsNothing);
      expect(find.textContaining('Unable to update checkout'), findsOneWidget);
    },
  );
  testWidgets('enabled separate shipping opens its own merchant form', (
    tester,
  ) async {
    final api = CheckoutFixture101()..separate = true;
    await open(tester, api);
    await fill(tester);
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();
    expect(api.types, ['billing', 'delivery']);
    expect(find.text('Shipping address'), findsOneWidget);
  });
  testWidgets('failed metadata never invents default address fields', (
    tester,
  ) async {
    final api = CheckoutFixture101()..failForm = true;
    await open(tester, api);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    api.failForm = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('المحافظة'), findsOneWidget);
  });
  testWidgets(
    'owner change discards pending address response and previous draft',
    (tester) async {
      final old = CheckoutFixture101()
        ..pendingForm = Completer<OdooAddressForm101>();
      await tester.pumpWidget(MaterialApp(home: OdooCheckoutForm101(api: old)));
      await tester.pump();
      final next = CheckoutFixture101();
      await open(tester, next);
      await tester.enterText(find.byType(TextFormField).first, 'Next owner');
      old.pendingForm!.complete(old.address(country: 2));
      await tester.pumpAndSettle();
      expect(find.text('Next owner'), findsOneWidget);
      expect(find.text('المحافظة'), findsOneWidget);
      expect(find.text('State'), findsNothing);
    },
  );
  if (AppConfig.commercePlatform == CommercePlatform.odoo) {
    testWidgets('Odoo cart renders its own basket and enters native checkout', (
      tester,
    ) async {
      final merchant = OdooMerchant100('alpha.odoo.example.invalid')
        ..quantity = 1;
      merchant.alterCart = (raw) {
        for (final item in (raw['cart'] as Map)['items'] as List) {
          (item as Map)['image_url'] = '';
        }
      };
      final client = odooTestClient100(merchant);
      final router = createAppRouter(initialLocation: '/cart');
      addTearDown(router.dispose);
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            odooCustomerClient51Provider.overrideWithValue(client),
            odooCheckout101Provider.overrideWith(
              (ref) async => CheckoutFixture101(),
            ),
            compactFamilyProvider.overrideWithValue(false),
            authRepositoryProvider.overrideWith(
              (ref) => throw StateError('Woo auth initialized'),
            ),
            hostedCommerceLauncher297Provider.overrideWithValue(
              (_) => throw StateError('Browser opened'),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Store-priced item'), findsOneWidget);
      expect(find.textContaining('135.79'), findsWidgets);
      await tester.tap(find.byKey(const Key('checkout-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('odoo-native-checkout')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    test(
      'Odoo add resolves the actual variant and rejects ambiguous or missing selection',
      () async {
        final merchant = OdooMerchant100('alpha.odoo.example.invalid');
        final client = odooTestClient100(merchant);
        final catalog = ProductFakeCatalogRepository(
          variations: [
            const CatalogVariation(id: 7, attributes: []),
            const CatalogVariation(id: 8, attributes: []),
          ],
        );
        final container = ProviderContainer(
          overrides: [
            odooCustomerClient51Provider.overrideWithValue(client),
            catalogRepositoryProvider.overrideWithValue(catalog),
            authRepositoryProvider.overrideWith(
              (ref) => throw StateError('Woo auth initialized'),
            ),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(client.close);
        final add = container.read(addProductPurchaseSelectionProvider);
        expect(
          (await add(
            ProductPurchaseSelection(productId: 42, catalogProductId: 42),
          )).succeeded,
          isFalse,
        );
        expect(
          (await add(ProductPurchaseSelection(productId: 42))).succeeded,
          isFalse,
        );
        expect(merchant.requests.where((r) => r.method == 'POST'), isEmpty);
        final added = await add(
          ProductPurchaseSelection(
            productId: 42,
            catalogProductId: 42,
            variantId: 7,
          ),
        );
        expect(added.succeeded, isTrue);
        expect(merchant.quantity, 1);
        expect(container.read(cartBadgeCountProvider), 1);
      },
    );
    testWidgets(
      'Odoo checkout route uses native widgets without Woo auth or browser',
      (tester) async {
        final router = createAppRouter(initialLocation: '/checkout');
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              odooCheckout101Provider.overrideWith(
                (ref) async => CheckoutFixture101(),
              ),
              authRepositoryProvider.overrideWith(
                (ref) => throw StateError('Woo auth initialized'),
              ),
              hostedCommerceLauncher297Provider.overrideWithValue(
                (_) => throw StateError('Browser opened'),
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('odoo-native-checkout')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
    test(
      'Odoo native cart badge reads actual server quantities without Woo auth',
      () async {
        final merchant = OdooMerchant100('alpha.odoo.example.invalid')
          ..quantity = 2;
        final client = odooTestClient100(merchant);
        final container = ProviderContainer(
          overrides: [
            odooCustomerClient51Provider.overrideWithValue(client),
            authRepositoryProvider.overrideWith(
              (ref) => throw StateError('Woo auth initialized'),
            ),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(client.close);
        final result = await container.read(cartControllerProvider.future);
        expect(result.cart.itemsCount, 2);
        expect(container.read(cartBadgeCountProvider), 2);
      },
    );
  }
}
