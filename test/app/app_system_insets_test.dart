import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kashier_flutter_sdk/kashier_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobishop_store_app/app/app.dart';
import 'package:mobishop_store_app/core/app_design/application_identity_provider58.dart';
import 'package:mobishop_store_app/features/checkout/presentation/checkout_screen.dart';

import '../features/checkout/support/checkout_test_data.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final language in ['en', 'ar']) {
    for (final bottom in [0.0, 24.0, 48.0]) {
      testWidgets('checkout stays above $bottom system inset in $language', (
        tester,
      ) async {
        _setView(tester, bottom: bottom, language: language);
        final repository = FakeCheckoutRepository();
        await _pumpApp(tester, (_) => CheckoutScreen(repository: repository));

        final scroll = find.byKey(const Key('checkout-form-scroll'));
        expect(tester.getRect(scroll).bottom, 800 - bottom);
        final state = tester.state<ScrollableState>(
          find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
        );
        state.position.jumpTo(state.position.maxScrollExtent);
        await tester.pumpAndSettle();
        final order = find.byKey(const Key('checkout-place-order'));
        final button = tester.getRect(order);
        expect(button.bottom, lessThanOrEqualTo(800 - bottom));
        // The lower edge of the button must remain tappable, not just its label.
        await tester.tapAt(Offset(button.center.dx, button.bottom - 4));
        await tester.pumpAndSettle();
        expect(repository.submitCalls, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('nested safe areas consume navigation inset only once', (
    tester,
  ) async {
    _setView(tester, bottom: 48);
    await _pumpApp(
      tester,
      (_) => const Scaffold(
        body: SafeArea(child: SizedBox.expand(key: Key('body'))),
        bottomNavigationBar: SafeArea(
          top: false,
          child: SizedBox(height: 50, key: Key('footer')),
        ),
      ),
    );
    expect(
      tester.getRect(find.byKey(const Key('footer'))),
      const Rect.fromLTWH(0, 702, 390, 50),
    );
    expect(tester.getRect(find.byKey(const Key('body'))).bottom, 702);
    // A navigation mode change is delivered by Flutter without restarting.
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('footer'))).bottom, 776);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('keyboard resize is preserved without an extra navigation gap', (
    tester,
  ) async {
    _setView(tester, bottom: 48);
    await _pumpApp(
      tester,
      (_) => const Scaffold(body: SizedBox.expand(key: Key('body'))),
    );
    expect(tester.getRect(find.byKey(const Key('body'))).bottom, 752);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    tester.view.padding = const FakeViewPadding(top: 24);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('body'))).bottom, 500);
    tester.view.viewInsets = const FakeViewPadding();
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 48);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const Key('body'))).bottom, 752);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final left in [true, false]) {
    testWidgets(
      'landscape reserves navigation on the ${left ? 'left' : 'right'}',
      (tester) async {
        _setView(tester, bottom: 0);
        tester.view.physicalSize = const Size(800, 390);
        final padding = FakeViewPadding(
          top: 24,
          left: left ? 48 : 0,
          right: left ? 0 : 48,
        );
        tester.view.padding = padding;
        tester.view.viewPadding = padding;
        await _pumpApp(
          tester,
          (_) => Scaffold(
            appBar: AppBar(title: const Text('Checkout')),
            body: const SizedBox.expand(key: Key('body')),
          ),
        );
        final body = tester.getRect(find.byKey(const Key('body')));
        expect(body.left, left ? 48 : 0);
        expect(body.right, left ? 800 : 752);
        // AppBar still owns the status-bar inset; it is not padded twice.
        expect(body.top, 24 + kToolbarHeight);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('root modal and snackbar stay above navigation buttons', (
    tester,
  ) async {
    _setView(tester, bottom: 48);
    await _pumpApp(
      tester,
      (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              builder: (_) => SizedBox(
                height: 100,
                child: TextButton(
                  key: const Key('sheet-action'),
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                  child: const Text('Close'),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final action = find.byKey(const Key('sheet-action'));
    expect(tester.getRect(action).bottom, 752);
    await tester.tap(action);
    await tester.pumpAndSettle();
    ScaffoldMessenger.of(
      tester.element(find.text('Open')),
    ).showSnackBar(const SnackBar(content: Text('Saved')));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(SnackBar)).bottom,
      lessThanOrEqualTo(752),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('SDK payment overlays inherit the protected viewport', (
    tester,
  ) async {
    _setView(tester, bottom: 48);
    await _pumpApp(tester, (_) => const Scaffold(body: Text('Checkout')));
    final provider = tester.state<KashierPaymentProviderState>(
      find.byType(KashierPaymentProvider),
    );
    // The SDK owns its overlay and MaterialApp outside the route Navigator.
    // Exercise that host without contacting a payment service.
    // ignore: invalid_use_of_internal_member
    provider.showPaymentSheet(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: TextButton(
              key: const Key('payment-action'),
              onPressed: provider.dismissPaymentSheet,
              child: const Text('Cancel'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final action = find.byKey(const Key('payment-action'));
    expect(tester.getRect(action).bottom, 752);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.text('Checkout'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

void _setView(
  WidgetTester tester, {
  required double bottom,
  String language = 'en',
}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 800);
  tester.view.padding = FakeViewPadding(top: 24, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: 24, bottom: bottom);
  tester.binding.platformDispatcher.localesTestValue = [Locale(language)];
  addTearDown(tester.view.reset);
  addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
}

Future<void> _pumpApp(WidgetTester tester, WidgetBuilder page) async {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (context, _) => page(context))],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [applicationIdentity58Provider.overrideWithValue(null)],
      child: MobiShopApp(router: router),
    ),
  );
  await tester.pumpAndSettle();
}
