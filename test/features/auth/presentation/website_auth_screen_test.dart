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
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/website_auth_providers.dart';

void main() {
  for (final checkout in [false, true]) {
    testWidgets(
      'verified account returns to ${checkout ? 'checkout' : 'home'}',
      (tester) async {
        final fixture = _Fixture();
        await fixture.pump(tester, checkout: checkout);
        expect(fixture.browserCalls, 1);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        fixture.complete();
        await tester.pumpAndSettle();
        expect(fixture.store.value?.user.id, 27);
        expect(find.text(checkout ? 'CHECKOUT 27' : 'HOME 27'), findsOneWidget);
        expect(
          fixture.router.routeInformationProvider.value.uri.toString(),
          checkout ? '/checkout?step=delivery&coupon=SAVE' : '/',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('cancel restores retry without account or automatic keyboard', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.pump(tester);
    fixture.result.completeError(PlatformException(code: 'CANCELED'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('website-auth-retry')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(fixture.store.value, isNull);
    expect(tester.testTextInput.isVisible, isFalse);
    fixture.result = Completer<String>();
    await tester.tap(find.byKey(const Key('website-auth-retry')));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(fixture.browserCalls, 2);
    fixture.complete();
    await tester.pumpAndSettle();
    expect(find.text('HOME 27'), findsOneWidget);
  });
}

class _Fixture {
  final store = MemoryAuthSessionStore();
  var result = Completer<String>();
  var state = '';
  var browserCalls = 0;
  late GoRouter router;
  late final Dio dio = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (r, h) {
          final Object data;
          if (r.path.endsWith('/start')) {
            state = r.data['state'] as String;
            data = {
              'authorize_url':
                  'https://store.example/?mobishop_login=${'a' * 64}',
            };
          } else {
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

  void complete() => result.complete(
    '${WebsiteAuthService.schemeFor(Uri.parse('https://store.example'))}://auth/complete?code=${'a' * 64}.${'b' * 64}&state=$state',
  );

  Future<void> pump(WidgetTester tester, {bool checkout = false}) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = WebsiteAuthService(
      store: Uri.parse('https://store.example'),
      dio: dio,
      sessions: store,
      browser: (_) {
        browserCalls++;
        return result.future;
      },
    );
    router = GoRouter(
      initialLocation: checkout
          ? '/checkout?step=delivery&coupon=SAVE'
          : '/auth',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Consumer(
            builder: (_, ref, _) => Scaffold(
              body: Text(
                'HOME ${ref.watch(authControllerProvider).value?.user.id}',
              ),
            ),
          ),
        ),
        GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
        GoRoute(
          path: '/checkout',
          builder: (_, _) => Consumer(
            builder: (_, ref, _) {
              final session = ref.watch(authControllerProvider).value;
              return session == null
                  ? const AuthScreen(popOnSuccess: false)
                  : Scaffold(body: Text('CHECKOUT ${session.user.id}'));
            },
          ),
        ),
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
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
        ),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}
