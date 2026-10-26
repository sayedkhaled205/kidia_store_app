import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_wishlist_button.dart';
import 'package:mobishop_store_app/shared/widgets/product/product_wishlist_appearance.dart';
import 'package:mobishop_store_app/features/wishlist/data/shared_preferences_wishlist_repository.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_client51.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/odoo_customer_providers51.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/features/wishlist/application/wishlist_access_provider.dart';

class _Session extends OdooCustomerSessionController51 {
  _Session(this.value);
  final Future<OdooCustomerSession51> value;
  @override
  Future<OdooCustomerSession51> build() => value;
}

OdooCustomerSession51 _signedIn(Duration remaining) => OdooCustomerSession51(
  expiresAt: DateTime.now().toUtc().add(remaining),
  customer: OdooCustomerProfile51(
    id: 7,
    partnerId: 7,
    name: 'Fixture',
    email: 'fixture@example.com',
    login: 'fixture',
    phone: '',
    mobile: '',
    address: OdooCustomerAddress51.fromJson({
      'id': 7,
      'type': 'contact',
      for (final key in [
        'name',
        'phone',
        'mobile',
        'street',
        'street2',
        'city',
        'zip',
        'country_code',
        'state_name',
      ])
        key: '',
    }),
  ),
);

void main() {
  final nativeOdoo =
      AppConfig.commercePlatform == CommercePlatform.odoo &&
      !AppConfig.isCmsPreview;
  testWidgets(
    'Odoo signed-out heart opens sign-in without saving a favorite',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: ProductWishlistButton(
                productId: 42,
                appearance: ProductWishlistAppearance(enabled: true),
              ),
            ),
          ),
          GoRoute(
            path: '/auth',
            builder: (_, _) => const Scaffold(body: Text('Odoo sign-in')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWith(
              (_) => throw StateError('Woo auth must never be used'),
            ),
            odooCustomerSession51Provider.overrideWith(
              () => _Session(Future.value(const OdooCustomerSession51())),
            ),
            cmsPageLayoutProvider('wishlist').overrideWith(
              (_) async => CmsPageLayout.fromJson({
                'page': 'wishlist',
                'settings': {'wishlist_access_mode': 'sign_in_required'},
              }),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('product-card-wishlist-42')));
      await tester.pumpAndSettle();
      expect(find.text('Odoo sign-in'), findsOneWidget);
      expect(
        await SharedPreferencesWishlistRepository.forConfiguredStore()
            .loadProductIds(),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
    skip: !nativeOdoo,
  );
  for (final mode in ['guest', 'sign_in_required']) {
    test(
      'Odoo $mode wishlist preserves platform isolation during restore and expiry',
      () async {
        final restore = Completer<OdooCustomerSession51>();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWith(
              (_) => throw StateError('Woo auth must never be used'),
            ),
            odooCustomerSession51Provider.overrideWith(
              () => _Session(restore.future),
            ),
            cmsPageLayoutProvider('wishlist').overrideWith(
              (_) async => CmsPageLayout.fromJson({
                'page': 'wishlist',
                'settings': {'wishlist_access_mode': mode},
              }),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(cmsPageLayoutProvider('wishlist').future);
        final initial = container.read(wishlistAccessProvider);
        expect(initial.requiresSignIn, mode == 'sign_in_required');
        expect(initial.loading, mode == 'sign_in_required');
        restore.complete(_signedIn(const Duration(hours: 1)));
        if (mode == 'sign_in_required') {
          await container.read(odooCustomerSession51Provider.future);
          expect(container.read(wishlistAccessProvider).signedIn, true);
          container.read(odooCustomerSession51Provider.notifier).state =
              AsyncData(_signedIn(const Duration(seconds: -1)));
          expect(container.read(wishlistAccessProvider).signedIn, false);
        }
      },
      skip: !nativeOdoo,
    );
  }
}
