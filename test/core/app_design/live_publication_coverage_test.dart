import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/app_design_bundle58.dart';
import 'package:mobishop_store_app/core/app_design/app_design_providers58.dart';
import 'package:mobishop_store_app/core/app_design/app_support_provider.dart';
import 'package:mobishop_store_app/core/app_design/app_ui_controls.dart';
import 'package:mobishop_store_app/core/app_design/app_ui_controls_provider.dart';
import 'package:mobishop_store_app/core/app_design/application_identity_provider58.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/features/account/presentation/odoo/odoo_support_screen56.dart';
import 'package:mobishop_store_app/features/checkout/presentation/checkout_presentation_provider.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

import 'app_design_fixture58.dart';

final _release = NotifierProvider<_Release, AppDesignBundle58>(_Release.new);

class _Release extends Notifier<AppDesignBundle58> {
  _Release([this.platform = CommercePlatform.odoo]);
  final CommercePlatform platform;
  @override
  AppDesignBundle58 build() => _bundle(platform, 'First', 'classic');
  void publish(String name, String checkout, {bool contacts = true}) =>
      state = _bundle(platform, name, checkout, contacts: contacts);
}

AppDesignBundle58 _bundle(
  CommercePlatform platform,
  String name,
  String checkout, {
  bool contacts = true,
}) {
  final json = appDesignFixture58();
  final origin = platform == CommercePlatform.shopify
      ? 'https://design-fixture.myshopify.com'
      : appDesignOrigin58;
  json['store_origin'] = origin;
  json['platform'] = switch (platform) {
    CommercePlatform.wooCommerce => 'woocommerce',
    CommercePlatform.shopify => 'shopify',
    CommercePlatform.odoo => 'odoo',
  };
  json['identity']['app_name'] = name;
  json['pages']['home']['settings']['checkout_presentation_v1'] = {
    'design': checkout,
  };
  json['pages']['home']['settings']['ui_controls_v1'] = {
    'support_whatsapp': '+20 1234567890',
    'support_contact_email': '$name@example.com',
    'support_email_enabled': contacts,
    'support_whatsapp_enabled': contacts,
    'auth_title_en': '$name sign in',
  };
  json['pages']['product']['settings']['publication_test'] = name;
  return AppDesignBundle58.fromEncoded(
    base64Encode(utf8.encode(jsonEncode(json))),
    platform: platform,
    storeOrigin: Uri.parse(origin),
  );
}

void main() {
  for (final platform in CommercePlatform.values) {
    test(
      '${platform.name}: repeated releases and rollback reach actual consumers',
      () async {
        final container = ProviderContainer(
          overrides: [
            _release.overrideWith(() => _Release(platform)),
            portableAppDesign58Provider.overrideWith(
              (ref) => ref.watch(_release),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.listen(checkoutPresentationProvider, (_, _) {});
        container.listen(appSupportProvider, (_, _) {});
        for (final step in [
          ('First', 'classic'),
          ('Second', 'compact'),
          ('Third', 'summary_first'),
          ('First', 'classic'),
        ]) {
          container.read(_release.notifier).publish(step.$1, step.$2);
          await container.read(cmsPageLayoutProvider('home').future);
          final checkout = await container.read(
            checkoutPresentationProvider.future,
          );
          expect(checkout.design.apiValue, step.$2);
          expect(
            container.read(applicationIdentity58Provider)!['app_name'],
            step.$1,
          );
          expect(
            container.read(appSupportProvider).email,
            '${step.$1}@example.com',
          );
          expect(container.read(appSupportProvider).whatsapp, '+20 1234567890');
          expect(
            container.read(appUiControlsProvider).text('auth_title', false, ''),
            '${step.$1} sign in',
          );
          expect(
            (await container.read(
              cmsPageLayoutProvider('product').future,
            )).settings['publication_test'],
            step.$1,
          );
        }
        container
            .read(_release.notifier)
            .publish('Hidden', 'classic', contacts: false);
        await container.read(cmsPageLayoutProvider('home').future);
        expect(container.read(appSupportProvider).email, isEmpty);
        expect(container.read(appSupportProvider).whatsapp, isEmpty);
      },
    );
  }

  test('malformed public contact values cannot become links', () {
    for (final value in [
      'javascript:alert(1)',
      'https://buyer@example.com',
      '<script>',
      'a\r\nb@example.com',
    ]) {
      final controls = AppUiControls.fromJson({
        'support_whatsapp': value,
        'support_contact_email': value,
      });
      expect(controls.values, isEmpty);
    }
  });

  testWidgets('mounted support screen receives new contacts and removal', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        portableAppDesign58Provider.overrideWith((ref) => ref.watch(_release)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: OdooSupportScreen56()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('First@example.com'), findsOneWidget);
    container.read(_release.notifier).publish('Second', 'compact');
    await tester.pumpAndSettle();
    expect(find.text('First@example.com'), findsNothing);
    expect(find.text('Second@example.com'), findsOneWidget);
    container
        .read(_release.notifier)
        .publish('Second', 'compact', contacts: false);
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
