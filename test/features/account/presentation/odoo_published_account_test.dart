import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobishop_store_app/core/app_design/app_ui_controls.dart';
import 'package:mobishop_store_app/core/app_design/application_identity_provider58.dart';
import 'package:mobishop_store_app/core/commerce/odoo_customer_client51.dart';
import 'package:mobishop_store_app/features/account/presentation/odoo/odoo_account_screen56.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/odoo_customer_providers51.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

class _Guest extends OdooCustomerSessionController51 {
  @override
  Future<OdooCustomerSession51> build() async => const OdooCustomerSession51();
}

void main() {
  testWidgets('legacy account button follows Arabic after publication', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          odooCustomerSession51Provider.overrideWith(_Guest.new),
          applicationIdentity58Provider.overrideWithValue({'app_name': 'Shop'}),
          cmsPageLayoutProvider('account').overrideWith(
            (ref) async => CmsPageLayout.fromJson({
              'page': 'account',
              'header': {'enabled': false},
              'footer': {'enabled': false},
              'elements': [
                {
                  'id': 'account_summary',
                  'enabled': true,
                  'settings': {'guest_title': 'Sign in / Create account'},
                },
              ],
            }),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: OdooAccountScreen56(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    expect(find.text('Sign in / Create account'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Odoo account consumes published identity, menu and avatar settings',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            odooCustomerSession51Provider.overrideWith(_Guest.new),
            authRepositoryProvider.overrideWith(
              (_) => throw StateError('No Woo authentication'),
            ),
            applicationIdentity58Provider.overrideWithValue({
              'app_name': 'Published shop',
            }),
            cmsPageLayoutProvider('account').overrideWith(
              (ref) async => CmsPageLayout.fromJson({
                'page': 'account',
                'settings': {'content_horizontal_padding': 28},
                'header': {'enabled': false},
                'footer': {'enabled': false},
                'elements': [
                  {
                    'id': 'account_summary',
                    'enabled': true,
                    'settings': {
                      'avatar_size': 40,
                      'card_style': 'outlined',
                      'guest_title': 'Join our shop',
                    },
                  },
                  {
                    'id': 'account_menu',
                    'enabled': true,
                    'settings': {
                      'show_orders': true,
                      'compact_family': true,
                      'show_addresses': false,
                      'show_profile': false,
                      'show_support': false,
                    },
                  },
                ],
              }),
            ),
          ],
          child: const MaterialApp(home: OdooAccountScreen56()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Published shop'), findsOneWidget);
      expect(find.text('Join our shop'), findsOneWidget);
      expect(find.text('My orders'), findsOneWidget);
      expect(find.text('Saved addresses'), findsNothing);
      expect(find.text('My profile'), findsNothing);
      expect(find.text('Customer service'), findsNothing);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.account_circle_outlined)).size,
        40,
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.widget<ListView>(find.byType(ListView)).padding,
        const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      );
      final cards = tester.widgetList<Card>(find.byType(Card)).toList();
      expect(cards.first.elevation, 0);
      expect(
        (cards.first.shape as RoundedRectangleBorder).side,
        isNot(BorderSide.none),
      );
      expect(cards.last.elevation, 0);
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'My orders'))
            .minTileHeight,
        64,
      );
    },
  );

  testWidgets('published auth controls retain typed login and Odoo action', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        odooCustomerSession51Provider.overrideWith(_Guest.new),
        authRepositoryProvider.overrideWith(
          (_) => throw StateError('No Woo authentication'),
        ),
        applicationIdentity58Provider.overrideWithValue({
          'app_name': 'Published shop',
        }),
      ],
    );
    addTearDown(container.dispose);
    Future<void> show(String title) => tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: AppUiControlsScope(
            controls: AppUiControls.fromJson({
              'auth_title_en': title,
              'auth_continue_en': 'Continue securely',
              'auth_side_padding': 30,
              'auth_field_radius': 20,
              'auth_background': '#F1F8F7',
              'auth_button_height': 60,
            }),
            child: const OdooSignInScreen56(),
          ),
        ),
      ),
    );
    await show('First title');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('odoo-login')),
      'buyer@example.com',
    );
    await show('Published title');
    await tester.pumpAndSettle();
    expect(find.text('First title'), findsNothing);
    expect(find.text('Published title'), findsOneWidget);
    expect(find.text('buyer@example.com'), findsOneWidget);
    expect(find.text('Continue securely'), findsOneWidget);
    expect(find.byKey(const Key('odoo-website-account-help')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
