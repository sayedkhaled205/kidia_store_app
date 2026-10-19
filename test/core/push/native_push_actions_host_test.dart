import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/core/push/foreground_push_notice.dart';
import 'package:mobishop_store_app/core/push/native_push_actions_host.dart';

void main() {
  testWidgets(
    'foreground content overlays current page and tap uses validated route',
    (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);
      await tester.pumpWidget(h.app());
      h.notices.add(_notice());
      await tester.pumpAndSettle();
      expect(find.text('Store home'), findsOneWidget);
      expect(find.text('New collection'), findsOneWidget);
      expect(find.text('Explore today'), findsOneWidget);
      expect(h.router.routeInformationProvider.value.uri.path, '/');
      await tester.tap(find.byKey(const Key('foreground-push-open')));
      await tester.pumpAndSettle();
      expect(h.router.routeInformationProvider.value.uri.path, '/product/42');
      expect(h.opens, hasLength(1));
      expect(find.byKey(const Key('foreground-push-banner')), findsNothing);
    },
  );

  testWidgets('dismiss and automatic expiry never navigate or record opening', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await tester.pumpWidget(h.app());
    h.notices.add(_notice());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('foreground-push-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('foreground-push-banner')), findsNothing);
    h.notices.add(_notice());
    await tester.pump();
    await tester.pump(const Duration(seconds: 8));
    expect(find.byKey(const Key('foreground-push-banner')), findsNothing);
    expect(h.opens, isEmpty);
    expect(h.router.routeInformationProvider.value.uri.path, '/');
  });

  testWidgets('invalid action displays text but cannot open unsafe URL', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await tester.pumpWidget(h.app());
    h.notices.add(
      _notice(
        data: {'destination': 'external', 'action_url': 'javascript:alert(1)'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('New collection'), findsOneWidget);
    expect(find.byKey(const Key('foreground-push-open')), findsNothing);
    await tester.tap(find.text('New collection'));
    await tester.pump();
    expect(h.opens, isEmpty);
    expect(h.router.routeInformationProvider.value.uri.path, '/');
    await tester.tap(find.byKey(const Key('foreground-push-dismiss')));
    await tester.pump();
  });

  testWidgets('store-change hint never becomes a customer banner', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await tester.pumpWidget(h.app());
    h.notices.add(
      _notice(data: {'type': 'mobishop_store_change', 'destination': 'home'}),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('foreground-push-banner')), findsNothing);
  });

  testWidgets('new notice replaces old one with a fresh expiry timer', (
    tester,
  ) async {
    final h = _Harness();
    addTearDown(h.dispose);
    await tester.pumpWidget(h.app());
    h.notices.add(_notice());
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    h.notices.add(
      ForegroundPushNotice(
        title: 'Order update',
        body: 'Packed',
        data: {'destination': 'cart'},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Order update'), findsOneWidget);
    expect(find.text('New collection'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const Key('foreground-push-banner')), findsNothing);
  });
}

ForegroundPushNotice _notice({Map<String, dynamic>? data}) =>
    ForegroundPushNotice(
      title: 'New collection',
      body: 'Explore today',
      data:
          data ??
          {
            'destination': 'product',
            'destination_id': '42',
            'notification_id': 'notice-1',
          },
    );

class _Harness {
  final notices = StreamController<ForegroundPushNotice>.broadcast();
  final opens = <Map<String, dynamic>>[];
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(body: Text('Store home')),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) => const Scaffold(body: Text('Product')),
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) => const Scaffold(body: Text('Cart')),
      ),
    ],
  );
  Widget app() => MaterialApp.router(
    routerConfig: router,
    builder: (context, child) => NativePushActionsHost(
      router: router,
      openedActions: const Stream.empty(),
      foregroundNotices: notices.stream,
      onForegroundOpened: (data) async {
        opens.add(data);
      },
      child: child!,
    ),
  );
  Future<void> dispose() async {
    router.dispose();
    await notices.close();
  }
}
