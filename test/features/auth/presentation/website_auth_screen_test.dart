import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/features/auth/data/network/auth_api_transport.dart';
import 'package:mobishop_store_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobishop_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:mobishop_store_app/features/auth/data/storage/social_auth_pending_store.dart';
import 'package:mobishop_store_app/features/auth/data/website_auth_service.dart';
import 'package:mobishop_store_app/features/auth/presentation/auth_screen.dart';
import 'package:mobishop_store_app/features/auth/presentation/embedded_store_auth_view.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/website_auth_providers.dart';

void main() {
  for (final route in [
    '/auth',
    '/checkout?step=delivery&coupon=SAVE',
    '/orders?status=paid',
    '/profile?tab=phone',
  ]) {
    testWidgets(
      'embedded sign-in preserves destination $route without opening browser',
      (tester) async {
        final fixture = _Fixture();
        await fixture.pump(tester, route: route);
        expect(fixture.browserUris, isEmpty);
        expect(find.byKey(const Key('embedded-sign-in')), findsOneWidget);
        fixture.embedded!.onComplete(fixture.callback());
        await tester.pumpAndSettle();
        expect(fixture.store.value?.user.id, 27);
        expect(
          fixture.router.routeInformationProvider.value.uri.toString(),
          route == '/auth' ? '/account' : route,
        );
        expect(find.text('CUSTOMER 27'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'standalone pushed login returns to the previous route and query',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester, route: '/account?tab=saved');
      fixture.router.push('/auth');
      await tester.pumpAndSettle();
      fixture.embedded!.onComplete(fixture.callback());
      await tester.pumpAndSettle();
      expect(
        fixture.router.routeInformationProvider.value.uri.toString(),
        '/account?tab=saved',
      );
      expect(fixture.browserUris, isEmpty);
    },
  );

  for (final useButton in [false, true]) {
    testWidgets(
      '${useButton ? 'explicit browser button' : 'external OAuth request'} starts a fresh handshake',
      (tester) async {
        final fixture = _Fixture();
        await fixture.pump(tester, route: '/checkout?coupon=SAVE');
        final embeddedUri = fixture.embedded!.uri;
        final oldCallback = fixture.callback();
        if (useButton) {
          await tester.tap(find.byKey(const Key('website-auth-browser')));
        } else {
          fixture.embedded!.onExternalAuthentication();
          await tester.pumpAndSettle();
          expect(fixture.browserUris, isEmpty);
          expect(fixture.starts.length, 1);
          await tester.tap(find.byKey(const Key('website-auth-browser')));
        }
        await _settleStart(tester);
        expect(fixture.starts.length, 2);
        expect(fixture.starts[0]['state'], isNot(fixture.starts[1]['state']));
        expect(
          fixture.starts[0]['challenge'],
          isNot(fixture.starts[1]['challenge']),
        );
        expect(fixture.browserUris.single, isNot(embeddedUri));
        expect(fixture.browserUris.single.origin, 'https://store.example');
        expect(fixture.exchanges, 0);
        expect(fixture.store.value, isNull);
        expect(fixture.callback(), isNot(oldCallback));
        fixture.browserResult.complete(fixture.callback());
        await tester.pumpAndSettle();
        expect(fixture.exchanges, 1);
        expect(fixture.store.value?.user.id, 27);
        expect(
          fixture.router.routeInformationProvider.value.uri.toString(),
          '/checkout?coupon=SAVE',
        );
      },
    );
  }

  testWidgets(
    'invalid embedded callback shows retry without exchange or saved session',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      fixture.embedded!.onComplete(
        fixture.callback().replaceFirst(fixture.state, 'f' * 64),
      );
      await tester.pumpAndSettle();
      expect(fixture.exchanges, 0);
      expect(fixture.store.value, isNull);
      expect(fixture.browserUris, isEmpty);
      expect(find.byKey(const Key('website-auth-retry')), findsOneWidget);
      await tester.tap(find.byKey(const Key('website-auth-retry')));
      await tester.pumpAndSettle();
      expect(fixture.starts.length, 2);
      fixture.embedded!.onComplete(fixture.callback());
      await tester.pumpAndSettle();
      expect(fixture.store.value?.user.id, 27);
    },
  );

  testWidgets(
    'system back cancels embedded login and allows retry without opening browser',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('website-auth-retry')), findsOneWidget);
      expect(fixture.store.value, isNull);
      expect(fixture.browserUris, isEmpty);
      expect(tester.testTextInput.isVisible, isFalse);
      await tester.tap(find.byKey(const Key('website-auth-retry')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('embedded-sign-in')), findsOneWidget);
      expect(fixture.starts.length, 2);
    },
  );

  testWidgets(
    'close abandons the pending attempt without publishing a session',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      await tester.tap(find.byKey(const Key('website-auth-close')));
      await tester.pumpAndSettle();
      expect(
        fixture.router.routeInformationProvider.value.uri.path,
        '/account',
      );
      expect(fixture.store.value, isNull);
      expect(fixture.exchanges, 0);
      expect(fixture.browserUris, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('close during exchange prevents a late session write', (
    tester,
  ) async {
    final fixture = _Fixture()..exchangeGate = Completer<void>();
    await fixture.pump(tester);
    fixture.embedded!.onComplete(fixture.callback());
    await _settleStart(tester);
    expect(fixture.exchanges, 1);
    await tester.tap(find.byKey(const Key('website-auth-close')));
    await tester.pumpAndSettle();
    fixture.exchangeGate!.complete();
    await tester.pumpAndSettle();
    expect(fixture.store.value, isNull);
    expect(find.text('CUSTOMER null'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'late browser callback after close cannot publish and a new attempt can start',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      await tester.tap(find.byKey(const Key('website-auth-browser')));
      await _settleStart(tester);
      final abandonedCallback = fixture.callback();
      await tester.tap(find.byKey(const Key('website-auth-close')));
      await tester.pumpAndSettle();
      fixture.router.push('/auth');
      await tester.pumpAndSettle();
      expect(fixture.starts.length, 3);
      expect(find.byKey(const Key('embedded-sign-in')), findsOneWidget);
      fixture.browserResult.complete(abandonedCallback);
      await tester.pumpAndSettle();
      expect(fixture.exchanges, 0);
      expect(fixture.store.value, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('browser cancellation returns to embedded retry', (tester) async {
    final fixture = _Fixture();
    await fixture.pump(tester);
    await tester.tap(find.byKey(const Key('website-auth-browser')));
    await _settleStart(tester);
    fixture.browserResult.completeError(PlatformException(code: 'CANCELED'));
    await tester.pumpAndSettle();
    expect(fixture.store.value, isNull);
    await tester.tap(find.byKey(const Key('website-auth-retry')));
    await tester.pumpAndSettle();
    expect(fixture.starts.length, 3);
    expect(fixture.browserUris.length, 1);
    expect(find.byKey(const Key('embedded-sign-in')), findsOneWidget);
  });
}

Future<void> _settleStart(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _Fixture {
  final store = MemoryAuthSessionStore();
  final browserResult = Completer<String>();
  final browserUris = <Uri>[];
  final starts = <Map<String, dynamic>>[];
  EmbeddedStoreAuthRequest? embedded;
  Completer<void>? exchangeGate;
  var exchanges = 0;
  String get state => starts.last['state'] as String;
  String get id => starts.length.toRadixString(16).padLeft(64, '0');
  late GoRouter router;
  late final Dio dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) async {
          final Object data;
          if (r.path.endsWith('/start')) {
            starts.add(Map<String, dynamic>.from(r.data as Map));
            data = {
              'authorize_url': 'https://store.example/?mobishop_login=$id',
            };
          } else {
            exchanges++;
            expect(r.path.endsWith('/exchange'), isTrue);
            expect(r.data['state'], state);
            if (exchangeGate != null) await exchangeGate!.future;
            data = {
              'token': 'test-session',
              'expires_at': DateTime.now()
                  .add(const Duration(days: 1))
                  .toIso8601String(),
              'user': {'id': 27, 'email': 'selected@example.com'},
            };
          }
          h.resolve(Response(requestOptions: r, statusCode: 200, data: data));
        },
      ),
    );

  String callback() =>
      '${WebsiteAuthService.schemeFor(Uri.parse('https://store.example'))}://auth/complete?code=$id.${'b' * 64}&state=$state';

  Future<void> pump(WidgetTester tester, {String route = '/auth'}) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = WebsiteAuthService(
      store: Uri.parse('https://store.example'),
      dio: dio,
      sessions: store,
      browser: (uri) {
        browserUris.add(uri);
        return browserResult.future;
      },
    );
    Widget account() => Consumer(
      builder: (_, ref, _) => Scaffold(
        body: Text(
          'CUSTOMER ${ref.watch(authControllerProvider).value?.user.id}',
        ),
      ),
    );
    Widget protected() => Consumer(
      builder: (_, ref, _) => ref.watch(authControllerProvider).value == null
          ? const AuthScreen(popOnSuccess: false)
          : account(),
    );
    router = GoRouter(
      initialLocation: route,
      routes: [
        GoRoute(path: '/', builder: (_, _) => account()),
        GoRoute(path: '/account', builder: (_, _) => account()),
        GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
        for (final path in ['/checkout', '/orders', '/profile'])
          GoRoute(path: path, builder: (_, _) => protected()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            AuthRepositoryImpl(
              transport: DioAuthApiTransport(
                storeUri: Uri.parse('https://store.example'),
                dio: dio,
              ),
              sessionStore: store,
              socialPendingStore: MemorySocialAuthPendingStore(),
            ),
          ),
          websiteAuthEnabledProvider.overrideWith((_) async => true),
          websiteAuthServiceProvider.overrideWithValue(auth),
          embeddedStoreAuthBuilderProvider.overrideWithValue((request) {
            embedded = request;
            return const SizedBox(key: Key('embedded-sign-in'));
          }),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}
