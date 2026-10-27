import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/app_design_bundle58.dart';
import 'package:mobishop_store_app/core/app_design/app_design_providers58.dart';
import 'package:mobishop_store_app/core/app_design/app_ui_controls.dart';
import 'package:mobishop_store_app/core/app_design/app_ui_controls_provider.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/auth_copy.dart';
import 'package:mobishop_store_app/features/cart/presentation/cart_copy.dart';
import 'package:mobishop_store_app/features/cart/presentation/widgets/cart_count_pulse.dart';
import 'app_design_fixture58.dart';

void main() {
  test(
    'cart choices and inherited sizes reject unsafe values independently',
    () {
      final controls = AppUiControls.fromJson({
        'cart_layout': 'compact',
        'cart_coupon_display': 'expanded',
        'cart_summary_display': 'javascript:alert(1)',
        'cart_item_image_radius': 0,
        'cart_item_image_width': null,
        'cart_item_image_height': 10000,
        'cart_checkout_button_height': 60,
      });
      expect(controls.values, {
        'cart_layout': 'compact',
        'cart_coupon_display': 'expanded',
        'cart_item_image_radius': 0,
        'cart_checkout_button_height': 60,
      });
    },
  );
  test(
    'schema-1 release carries controls through the actual page provider',
    () async {
      final payload = appDesignFixture58();
      payload['pages']['home']['settings']['ui_controls_v1'] = {
        'logout_height': 48,
        'cart_title_ar': 'مشترياتي',
      };
      final bundle = AppDesignBundle58.fromEncoded(
        base64Encode(utf8.encode(jsonEncode(payload))),
        platform: CommercePlatform.odoo,
        storeOrigin: Uri.parse(appDesignOrigin58),
      );
      final container = ProviderContainer(
        overrides: [portableAppDesign58Provider.overrideWithValue(bundle)],
      );
      addTearDown(container.dispose);
      await container.read(cmsPageLayoutProvider('home').future);
      final controls = container.read(appUiControlsProvider);
      expect(controls.number('logout_height'), 48);
      expect(controls.text('cart_title', true, 'السلة'), 'مشترياتي');
      expect(controls.text('cart_title', false, 'Bag'), 'Bag');
    },
  );
  test(
    'invalid or unsafe fields fall back independently without enabling behavior',
    () {
      final config = AppUiControls.fromJson({
        'auth_title_size': 900,
        'auth_background': 'url(https://invalid)',
        'auth_title_en': '<script>',
        'cart_pulse_enabled': 'false',
        'auth_side_padding': double.nan,
        'logout_height': 45,
        'auth_continue_en': ' Continue shopping ',
        'skip_auth': true,
      });
      expect(config.number('auth_title_size'), 23);
      expect(config.color('auth_background'), Colors.white);
      expect(config.number('auth_side_padding'), 24);
      expect(config.boolean('cart_pulse_enabled'), true);
      expect(config.text('auth_title', false, 'Default'), 'Default');
      expect(config.number('logout_height'), 45);
      expect(
        config.text('auth_continue', false, 'Default'),
        'Continue shopping',
      );
      expect(config.values.containsKey('skip_auth'), false);
    },
  );

  testWidgets('published text changes and rollback refresh existing widgets', (
    tester,
  ) async {
    Future<void> show(Map<String, dynamic> settings) => tester.pumpWidget(
      MaterialApp(
        home: AppUiControlsScope(
          controls: AppUiControls.fromJson(settings),
          child: Builder(
            builder: (context) {
              final auth = AuthCopy.of(context), cart = CartCopy.of(context);
              return Column(
                children: [
                  Text(auth.title),
                  Text(auth.continueLabel),
                  Text(cart.compactTitle),
                  Text(cart.checkout),
                ],
              );
            },
          ),
        ),
      ),
    );
    await show({
      'auth_title_en': 'Welcome back',
      'auth_continue_en': 'Next',
      'cart_title_en': 'Your bag',
      'cart_checkout_en': 'Place order',
    });
    for (final text in ['Welcome back', 'Next', 'Your bag', 'Place order']) {
      expect(find.text(text), findsOneWidget);
    }
    await show({});
    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('Sign in or create an account'), findsOneWidget);
    expect(find.text('Bag'), findsOneWidget);
  });

  testWidgets(
    'remote pulse toggle, scale and duration respect reduced motion',
    (tester) async {
      Future<void> show(
        int count, {
        bool enabled = true,
        bool reduced = false,
      }) => tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: AppUiControlsScope(
              controls: AppUiControls.fromJson({
                'cart_pulse_enabled': enabled,
                'cart_pulse_scale': 1.1,
                'cart_pulse_duration': 1000,
              }),
              child: CartCountPulse(count: count, child: Text('$count')),
            ),
          ),
        ),
      );
      double scale() => tester
          .widget<ScaleTransition>(find.byKey(const Key('cart-count-pulse')))
          .scale
          .value;
      await show(1);
      expect(scale(), 1);
      await show(2);
      await tester.pump(const Duration(milliseconds: 450));
      expect(scale(), closeTo(1.1, .001));
      await tester.pump(const Duration(milliseconds: 550));
      expect(scale(), 1);
      await show(3, enabled: false);
      await tester.pump(const Duration(milliseconds: 450));
      expect(scale(), 1);
      await show(4, reduced: true);
      await tester.pump(const Duration(milliseconds: 450));
      expect(scale(), 1);
      await show(5);
      await tester.pump(const Duration(milliseconds: 450));
      expect(scale(), closeTo(1.1, .001));
      await show(5, enabled: false);
      expect(scale(), 1);
    },
  );
}
