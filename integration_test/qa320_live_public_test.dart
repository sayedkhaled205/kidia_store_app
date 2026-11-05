// QA-only. Runs the real application and real public endpoints, without mocks.
// Never submits identifiers, starts OAuth/OTP, mutates a cart, or places orders.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobishop_store_app/main.dart' as app;
import 'package:mobishop_store_app/features/catalog/presentation/pages/catalog_product_list_screen.dart';
import 'package:mobishop_store_app/features/account/presentation/account_screen.dart';
import 'package:mobishop_store_app/features/account/presentation/store_privacy_screen.dart';
import 'package:mobishop_store_app/features/auth/presentation/auth_screen.dart';
import 'package:mobishop_store_app/features/cart/presentation/cart_screen.dart';
import 'package:mobishop_store_app/features/cart/presentation/cart_copy.dart';
import 'package:mobishop_store_app/features/product/presentation/product_detail_screen.dart';
import 'package:mobishop_store_app/features/product/presentation/product_image_gallery.dart';
import 'package:mobishop_store_app/shared/widgets/product/store_product_card.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.defaultTestTimeout = const Timeout(Duration(minutes: 7));

  testWidgets(
    'real public iOS storefront: auth policy cancel gallery zoom and guest checkout gate',
    (tester) async {
      final checks = <String>[];
      Future<void> record(String name) async {
        checks.add(name);
        binding.reportData ??= <String, dynamic>{};
        binding.reportData!.addAll({
          'live_public_checks': List<String>.of(checks),
          'network': 'real public endpoints',
          'account_submissions': 0,
          'cart_mutations': 0,
          'orders': 0,
          'payments': 0,
        });
        await binding.takeScreenshot('ios320-live-$name');
        debugPrint('IOS320_LIVE_PASS $name');
      }

      Future<void> waitFor(
        Finder finder,
        String reason, {
        Duration timeout = const Duration(seconds: 55),
      }) async {
        final end = DateTime.now().add(timeout);
        while (finder.evaluate().isEmpty && DateTime.now().isBefore(end)) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        expect(finder, findsWidgets, reason: reason);
        await tester.pump(const Duration(milliseconds: 500));
      }

      app.main();
      await waitFor(
        find.byKey(const Key('cms-bottom-navigation')),
        'real configured storefront footer must render',
      );
      await record('01-startup');
      final router = GoRouter.of(
        tester.element(find.byKey(const Key('cms-bottom-navigation'))),
      );

      // Real production routes; no provider overrides or synthesized responses.
      final failures = <String>[];
      Future<void> phase(String label, Future<void> Function() action) async {
        try {
          await action();
        } catch (error, stack) {
          failures.add('$label: $error');
          debugPrint('IOS320_LIVE_FAIL $label: $error\n$stack');
          try {
            await binding.takeScreenshot('ios320-live-error-$label');
          } catch (_) {}
        }
      }

      await phase('auth', () async {
        router.go('/account');
        await waitFor(find.byType(AccountScreen), 'account page must open');
        await waitFor(
          find.byKey(const Key('account-sign-in')),
          'fresh simulator must be signed out; stop rather than use an existing account',
        );
        await tester.ensureVisible(find.byKey(const Key('account-sign-in')));
        await tester.tap(find.byKey(const Key('account-sign-in')));
        await waitFor(find.byType(AuthScreen), 'real auth screen must open');
        await waitFor(
          find.byKey(const Key('auth-email')),
          'public native-auth settings must load',
        );
        await record('02-login-open');

        // An unsubmitted reserved-domain value verifies form preservation. It is
        // never sent to the merchant, and is not a customer/account fixture.
        const identifier = 'qa-policy-return@example.invalid';
        binding.testTextInput.register();
        addTearDown(binding.testTextInput.unregister);
        await tester.enterText(find.byKey(const Key('auth-email')), identifier);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.ensureVisible(
          find.byKey(const Key('store-privacy-policy')),
        );
        await tester.tap(find.byKey(const Key('store-privacy-policy')));
        await waitFor(
          find.byType(StorePrivacyScreen),
          'in-app privacy reader must open',
        );
        await waitFor(
          find.descendant(
            of: find.byType(StorePrivacyScreen),
            matching: find.byType(SelectableText),
          ),
          'real fetched policy must contain readable blocks',
        );
        expect(find.byKey(const Key('store-privacy-retry')), findsNothing);
        await record('03-live-policy-content');
        await tester.pageBack();
        await waitFor(
          find.byKey(const Key('auth-email')),
          'policy back must restore auth form',
        );
        final field = tester.widget<TextField>(
          find.descendant(
            of: find.byKey(const Key('auth-email')),
            matching: find.byType(TextField),
          ),
        );
        expect(
          field.controller?.text,
          identifier,
          reason: 'policy back must preserve unsubmitted input',
        );
        await record('04-policy-back-preserves-form');
        await tester.tap(find.byKey(const Key('auth-close')));
        await waitFor(
          find.byType(AccountScreen),
          'auth cancel must return to account',
        );
        expect(find.byType(AuthScreen), findsNothing);
        await record('05-login-cancel');
      });
      await phase('gallery', () async {
        router.go('/products');
        await waitFor(
          find.byType(CatalogProductListScreen),
          'catalog route must replace the previous page',
        );
        final readyCards = find.descendant(
          of: find.byType(CatalogProductListScreen),
          matching: find.byWidgetPredicate(
            (widget) => widget is StoreProductCard && widget.onTap != null,
          ),
        );
        await waitFor(
          readyCards,
          'real catalog must finish loading an actionable product',
        );
        final cardFinder = readyCards.first;
        await tester.ensureVisible(cardFinder);
        await tester.tap(cardFinder);
        await waitFor(
          find.byType(ProductDetailScreen),
          'real public product detail must open',
        );
        await waitFor(
          find.byKey(const Key('open-product-image-0')),
          'real public product must expose gallery',
        );
        await tester.ensureVisible(
          find.byKey(const Key('open-product-image-0')),
        );
        await tester.tap(find.byKey(const Key('open-product-image-0')));
        await waitFor(
          find.byType(ProductImageGallery),
          'fullscreen gallery must open',
        );
        await record('06-live-gallery-open');
        final viewerFinder = find
            .byKey(const Key('fullscreen-image-zoom'))
            .first;
        final center = tester.getCenter(viewerFinder);
        final first = await tester.startGesture(
          center - const Offset(40, 0),
          pointer: 1,
        );
        final second = await tester.startGesture(
          center + const Offset(40, 0),
          pointer: 2,
        );
        await first.moveTo(center - const Offset(140, 0));
        await second.moveTo(center + const Offset(140, 0));
        await tester.pump();
        await first.up();
        await second.up();
        await tester.pump(const Duration(milliseconds: 700));
        final viewer = tester.widget<InteractiveViewer>(viewerFinder);
        expect(
          viewer.transformationController!.value.getMaxScaleOnAxis(),
          greaterThan(1.1),
        );
        await record('07-live-gallery-pinch-zoom');
        await tester.tap(find.byKey(const Key('product-gallery-back')));
        await waitFor(
          find.byType(ProductDetailScreen),
          'gallery back must restore real product',
        );
        expect(find.byType(ProductImageGallery), findsNothing);
        await record('08-live-gallery-back');
      });
      await phase('cart-checkout-gate', () async {
        router.go('/cart');
        await waitFor(find.byType(CartScreen), 'real guest cart must open');
        await waitFor(
          find.text(
            CartCopy.of(tester.element(find.byType(CartScreen))).emptyTitle,
          ),
          'fresh guest cart must be empty; no cart mutation is allowed',
        );
        await record('09-live-empty-cart');
        // Route gate is tested directly because adding merchandise would mutate
        // the live WooCommerce cart. No checkout repository may be entered.
        unawaited(router.push<void>('/checkout'));
        await waitFor(
          find.byType(AuthScreen),
          'guest checkout must be gated by authentication',
        );
        await waitFor(
          find.byKey(const Key('auth-email')),
          'checkout gate must load public auth settings',
        );
        await record('10-live-checkout-guest-gate');
        await tester.tap(find.byKey(const Key('auth-close')));
        await waitFor(
          find.byType(CartScreen),
          'checkout auth cancel must return to cart',
        );
        expect(find.byType(AuthScreen), findsNothing);
        await record('11-checkout-gate-cancel');
      });
      binding.reportData!['phase_failures'] = failures;
      expect(failures, isEmpty, reason: failures.join('\n'));
      expect(tester.takeException(), isNull);
    },
  );
}
