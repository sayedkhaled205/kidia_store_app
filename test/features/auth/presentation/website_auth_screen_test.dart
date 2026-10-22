import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/core/app_design/application_identity_provider58.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/native_auth.dart';
import 'package:mobishop_store_app/features/auth/presentation/auth_screen.dart';
import 'package:mobishop_store_app/features/auth/presentation/embedded_store_auth_view.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/native_auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/website_auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/website_auth_screen.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

void main() {
  testWidgets(
    'website capability cannot replace native sign-in or open a browser',
    (tester) async {
      var websiteServiceReads = 0;
      final actions = _NativeActions();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_SignedOutController.new),
          nativeAuthActionsProvider.overrideWithValue(actions),
          nativeAuthConfigProvider.overrideWith(
            (_) async =>
                const NativeAuthConfig(methods: {'email_password': true}),
          ),
          websiteAuthEnabledProvider.overrideWith((_) async => true),
          websiteAuthServiceProvider.overrideWith((_) {
            websiteServiceReads++;
            throw StateError(
              'Native login must not create website authentication',
            );
          }),
          applicationIdentity58Provider.overrideWithValue({
            'app_name': 'متجر الاختبار',
          }),
          cmsPageLayoutProvider('account').overrideWith(
            (_) async => CmsPageLayout.fromJson({'page': 'account'}),
          ),
        ],
      );
      addTearDown(container.dispose);
      expect(await container.read(websiteAuthEnabledProvider.future), isTrue);
      final router = GoRouter(
        initialLocation: '/auth',
        routes: [
          GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
          GoRoute(path: '/account', builder: (_, _) => const Scaffold()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(WebsiteAuthScreen), findsNothing);
      expect(find.byType(EmbeddedStoreAuthView), findsNothing);
      expect(find.byKey(const Key('website-auth-browser')), findsNothing);
      expect(find.byKey(const Key('auth-email')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'test@example.com',
      );
      await tester.tap(find.byKey(const Key('auth-continue')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-password')), findsOneWidget);
      expect(actions.identifyCalls, 1);
      expect(websiteServiceReads, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

class _SignedOutController extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
}

class _NativeActions implements NativeAuthActions {
  int identifyCalls = 0;
  @override
  Future<NativeAuthIdentity> identify(String identifier) async {
    identifyCalls++;
    return NativeAuthIdentity(
      identifier: identifier,
      kind: 'email',
      methods: ['password'],
    );
  }

  @override
  Future<void> cancel() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
