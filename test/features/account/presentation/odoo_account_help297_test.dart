import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/app/app_router.dart';
import 'package:mobishop_store_app/app/hosted_commerce_screen297.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_client51.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/app_design/application_identity_provider58.dart';
import 'package:mobishop_store_app/features/account/presentation/odoo/odoo_account_screen56.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/odoo_customer_providers51.dart';

void main() {
  final notOdoo = AppConfig.commercePlatform != CommercePlatform.odoo;

  testWidgets(
    'Odoo account help opens its own HTTPS login and browser return stays signed out',
    (tester) async {
      final opened = <Uri>[];
      final controller = _GuestController();
      final container = ProviderContainer(
        overrides: [
          // This authentication contract has no embedded design. Branding is
          // exercised with real published bundles in the publication tests.
          applicationIdentity58Provider.overrideWithValue(null),
          odooCustomerSession51Provider.overrideWith(() => controller),
          authRepositoryProvider.overrideWith(
            (_) => throw StateError('Woo auth must not initialize for Odoo'),
          ),
          hostedCommerceLauncher297Provider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
      );
      addTearDown(container.dispose);
      final router = createAppRouter(initialLocation: '/auth');
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('odoo-login')),
        'customer@example.com',
      );
      final help = find.byKey(const Key('odoo-website-account-help'));
      await tester.ensureVisible(help);
      await tester.tap(help);
      await tester.pumpAndSettle();

      expect(opened, [
        AppConfig.commerceConnection.storeOrigin.resolve('/web/login'),
      ]);
      expect(opened.single.scheme, 'https');
      expect(opened.single.queryParameters, isEmpty);
      expect(find.byKey(const Key('hosted-commerce-screen')), findsOneWidget);
      expect(controller.signInCalls, 0);
      expect(
        container
            .read(odooCustomerSession51Provider)
            .requireValue
            .authenticated,
        isFalse,
      );

      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(OdooSignInScreen56), findsOneWidget);
      expect(find.text('customer@example.com'), findsOneWidget);
      expect(find.byKey(const Key('odoo-login-submit')), findsOneWidget);
      expect(controller.signInCalls, 0);
      expect(opened, hasLength(1));
      expect(
        container
            .read(odooCustomerSession51Provider)
            .requireValue
            .authenticated,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
    skip: notOdoo,
  );

  testWidgets(
    'expired Odoo session has a retry that restores usable guest sign-in',
    (tester) async {
      var restores = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            applicationIdentity58Provider.overrideWithValue(null),
            odooCustomerSession51Provider.overrideWith(
              () => _GuestController(
                restore: () async {
                  restores++;
                  if (restores == 1) {
                    throw const OdooCustomerException51(
                      'customer_session_required',
                      statusCode: 401,
                    );
                  }
                  return const OdooCustomerSession51();
                },
              ),
            ),
            authRepositoryProvider.overrideWith(
              (_) => throw StateError('Woo auth must not initialize for Odoo'),
            ),
          ],
          child: const MaterialApp(
            home: OdooCustomerGate56(child: Text('PRIVATE ACCOUNT CONTENT')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Your account session ended. Please sign in again.'),
        findsOneWidget,
      );
      expect(find.text('PRIVATE ACCOUNT CONTENT'), findsNothing);
      expect(find.byKey(const Key('odoo-login')), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(restores, 2);
      expect(find.byType(OdooSignInScreen56), findsOneWidget);
      expect(find.byKey(const Key('odoo-login')), findsOneWidget);
      expect(find.byKey(const Key('odoo-password')), findsOneWidget);
      expect(
        find.byKey(const Key('odoo-website-account-help')),
        findsOneWidget,
      );
      expect(find.text('PRIVATE ACCOUNT CONTENT'), findsNothing);
      expect(tester.takeException(), isNull);
    },
    skip: notOdoo,
  );

  testWidgets(
    'Odoo account help waits for session restoration before becoming usable',
    (tester) async {
      final restore = Completer<OdooCustomerSession51>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            applicationIdentity58Provider.overrideWithValue(null),
            odooCustomerSession51Provider.overrideWith(
              () => _GuestController(restore: () => restore.future),
            ),
          ],
          child: const MaterialApp(home: OdooSignInScreen56()),
        ),
      );
      await tester.pump();
      final help = find.byKey(const Key('odoo-website-account-help'));
      expect(tester.widget<TextButton>(help).onPressed, isNull);
      restore.complete(const OdooCustomerSession51());
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(help).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
    skip: notOdoo,
  );
}

class _GuestController extends OdooCustomerSessionController51 {
  _GuestController({this.restore});

  final Future<OdooCustomerSession51> Function()? restore;
  var signInCalls = 0;

  @override
  Future<OdooCustomerSession51> build() async =>
      restore == null ? const OdooCustomerSession51() : await restore!();

  @override
  Future<void> signIn({required String login, required String password}) async {
    signInCalls++;
    throw const OdooCustomerException51('invalid_credentials');
  }
}
