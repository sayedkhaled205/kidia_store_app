import 'package:mobishop_store_app/features/account/data/storage/account_deletion_receipt_store.dart';
import 'package:mobishop_store_app/features/account/presentation/account_deletion_screen.dart';
import 'package:mobishop_store_app/features/account/presentation/store_privacy_body_loader.dart';
import '../../../support/viewport_rotation.dart';
import 'package:mobishop_store_app/core/app_design/store_privacy_provider.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/features/account/presentation/account_screen.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/preview_identity_provider.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_identity.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/social_auth.dart';
import 'package:mobishop_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobishop_store_app/features/auth/presentation/auth_screen.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/native_auth_providers.dart';

import '../../auth/support/idle_native_auth_actions.dart';

void main() {
  for (final screenSize in [const Size(375, 812), const Size(390, 844)]) {
  for (final language in ['en', 'ar']) {
  for (final hasReceipt in [false, true]) {
  testWidgets('iPhone $screenSize $language receipt=$hasReceipt published account cards fit above navigation', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = screenSize;
    tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 44, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_SignedInRepository()),
        accountDeletionAvailabilityProvider.overrideWith((ref) async => true),
        accountDeletionReceiptProvider.overrideWith((ref) async => hasReceipt
            ? const AccountDeletionReceipt(receipt: 'fixture', userId: 7, sessionHash: 'fixture')
            : null),
        storePrivacyProvider.overrideWithValue(Uri.parse('https://merchant.example/privacy')),
        cmsPageLayoutProvider('account').overrideWith((ref) async {
          final base = CmsPageLayout.fallback('account');
          return CmsPageLayout(page: base.page, header: base.header, footer: base.footer,
            elements: [for (final element in base.elements) CmsPageComponent(
              id: element.id, type: element.type, enabled: element.enabled,
              settings: {...element.settings, if (element.id == 'account_menu') 'compact_family': false},
            )]);
        }),
      ],
      child: MaterialApp(theme: ThemeData(platform: TargetPlatform.iOS),
        locale: Locale(language),
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const Scaffold(body: AccountScreen(), bottomNavigationBar: SafeArea(child: SizedBox(height: 64)))),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-deletion-status')), findsNothing);
    final privacy = tester.getRect(find.byKey(const Key('store-privacy-policy')));
    final deletion = tester.getRect(find.byKey(const Key('account-delete')));
    final languageTile = tester.getRect(find.byKey(const Key('account-language')));
    expect(privacy.center.dy, closeTo(deletion.center.dy, 1));
    expect(privacy.top - languageTile.bottom, greaterThanOrEqualTo(8));
    for (final key in ['account-action-orders', 'account-action-addresses', 'account-action-profile', 'account-action-support', 'account-language', 'account-delete', 'account-sign-out']) {
      expect(find.byKey(Key(key)).hitTestable(), findsOneWidget, reason: key);
      expect(tester.getSize(find.byKey(Key(key))).height, greaterThanOrEqualTo(44), reason: key);
    }
    expect(tester.state<ScrollableState>(find.byType(Scrollable).first).position.maxScrollExtent, 0);
    expect(tester.takeException(), isNull);
  });
  }
  }
  }

  viewportRotationTests(
    'Account',
    (tester, size) => tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(
            _SignedInRepository('customer@example.com'),
          ),
        ],
        child: const MaterialApp(home: AccountScreen()),
      ),
    ),
  );
  for (final email in [
    '',
    'guest-201000000000@no-email.invalid',
    'real@gmail.com',
  ]) {
    testWidgets('account subtitle hides placeholder email: $email', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              _SignedInRepository(email),
            ),
          ],
          child: const MaterialApp(home: AccountScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Customer'), findsOneWidget);
      if (email.isNotEmpty) {
        expect(
          find.text(email),
          email == 'real@gmail.com' ? findsOneWidget : findsNothing,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('legacy English guest title follows Arabic app language', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedOutRepository()),
          storePrivacyProvider.overrideWithValue(
            Uri.parse('https://merchant.example/privacy'),
          ),
          storePrivacyBodyLoaderProvider.overrideWithValue((uri) async {
            expect(uri.toString(), 'https://merchant.example/privacy');
            return [];
          }),
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
                {'id': 'account_menu', 'enabled': false},
              ],
            }),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: AccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الدخول / إنشاء حساب'), findsOneWidget);
    expect(find.text('Sign in / Create account'), findsNothing);
    expect(find.byKey(const Key('store-privacy-policy')), findsOneWidget);
    await tester.tap(find.byKey(const Key('store-privacy-policy')));
    expect(tester.takeException(), isNull);
  });
  for (final selected in ['orders', 'addresses', 'profile', 'support']) {
    testWidgets('account menu shows only the configured action: $selected', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_SignedOutRepository()),
            cmsPageLayoutProvider('account').overrideWith(
              (ref) async => CmsPageLayout.fromJson({
                'page': 'account',
                'header': {'enabled': false},
                'footer': {'enabled': false},
                'elements': [
                  {
                    'id': 'account_summary',
                    'enabled': true,
                    'settings': {
                      'guest_title': 'عنوان الدخول المخصص',
                      'avatar_size': 40,
                      'card_style': 'minimal',
                    },
                  },
                  {
                    'id': 'account_menu',
                    'enabled': true,
                    'settings': {
                      for (final action in [
                        'orders',
                        'addresses',
                        'profile',
                        'support',
                      ])
                        'show_$action': action == selected,
                    },
                  },
                  {'id': 'logout_button', 'enabled': true},
                ],
              }),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const AccountScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final action in ['orders', 'addresses', 'profile', 'support']) {
        expect(
          find.byKey(Key('account-action-$action')),
          action == selected ? findsOneWidget : findsNothing,
        );
      }
      expect(find.text('عنوان الدخول المخصص'), findsOneWidget);
      expect(find.byKey(const Key('account-sign-out')), findsNothing);
      final card = tester.widget<Card>(find.byType(Card).first);
      expect(card.elevation, 0);
      expect((card.shape! as RoundedRectangleBorder).side, BorderSide.none);
      expect(
        Directionality.of(tester.element(find.byType(AccountScreen))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    });
  }

  for (final visible in <bool>[false, true]) {
    testWidgets('saved account email/logout and avatar settings: $visible', (
      tester,
    ) async {
      final avatar = visible ? 90.0 : 40.0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_SignedInRepository()),
            cmsPageLayoutProvider('account').overrideWith(
              (ref) async => CmsPageLayout.fromJson({
                'page': 'account',
                'header': {'enabled': false},
                'footer': {'enabled': false},
                'elements': [
                  {
                    'id': 'account_summary',
                    'enabled': true,
                    'settings': {
                      'show_email': visible,
                      'avatar_size': avatar,
                      'card_style': 'outlined',
                    },
                  },
                  {'id': 'account_menu', 'enabled': false},
                  {'id': 'logout_button', 'enabled': visible},
                ],
              }),
            ),
          ],
          child: const MaterialApp(home: AccountScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('customer@example.com'),
        visible ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const Key('account-sign-out')),
        visible ? findsOneWidget : findsNothing,
      );
      expect(find.byKey(const Key('account-action-orders')), findsNothing);
      final avatarBox = find
          .ancestor(
            of: find.byIcon(Icons.person_rounded),
            matching: find.byType(Container),
          )
          .first;
      expect(tester.getSize(avatarBox), Size(avatar, avatar));
      final card = tester.widget<Card>(find.byType(Card).first);
      expect(
        (card.shape! as RoundedRectangleBorder).side.style,
        BorderStyle.solid,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('preview guest account subtitle omits the selected application name', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedOutRepository()),
          previewIdentityProvider.overrideWith(
            (ref) => Stream.value({'app_name': 'كيديا ستور'}),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const AccountScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تابع طلباتك وبياناتك'), findsOneWidget);
  }, skip: !AppConfig.isCmsPreview);

  testWidgets(
    'private signed-out account actions require the same auth screen',
    (WidgetTester tester) async {
      final GoRouter router = GoRouter(
        initialLocation: '/account',
        routes: <RouteBase>[
          GoRoute(
            path: '/account',
            builder: (BuildContext context, GoRouterState state) =>
                const AccountScreen(),
          ),
          GoRoute(
            path: '/auth',
            builder: (BuildContext context, GoRouterState state) =>
                const AuthScreen(),
          ),
          GoRoute(
            path: '/cart',
            builder: (BuildContext context, GoRouterState state) =>
                const SizedBox.shrink(),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_SignedOutRepository()),
            nativeAuthActionsProvider.overrideWithValue(
              IdleNativeAuthActions(),
            ),
          ],
          child: MaterialApp.router(
            locale: const Locale('ar'),
            supportedLocales: const <Locale>[Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final List<Key> entryPoints = <Key>[
        const Key('account-sign-in'),
        const Key('account-action-orders'),
        const Key('account-action-addresses'),
        const Key('account-action-profile'),
      ];
      for (final Key key in entryPoints) {
        await tester.ensureVisible(find.byKey(key));
        await tester.tap(find.byKey(key));
        await tester.pumpAndSettle();
        expect(find.byType(AuthScreen), findsOneWidget);
        expect(find.byKey(const Key('auth-email')), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('auth-close')));
        await tester.pumpAndSettle();
        expect(find.byType(AccountScreen), findsOneWidget);
      }
    },
  );

  testWidgets('signed-in account actions open their real destinations', (
    WidgetTester tester,
  ) async {
    final GoRouter router = GoRouter(
      initialLocation: '/account',
      routes: <RouteBase>[
        GoRoute(
          path: '/account',
          builder: (BuildContext context, GoRouterState state) =>
              const AccountScreen(),
        ),
        GoRoute(
          path: '/orders',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: SizedBox(key: Key('orders-destination'))),
        ),
        GoRoute(
          path: '/addresses',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: SizedBox(key: Key('addresses-destination'))),
        ),
        GoRoute(
          path: '/profile',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: SizedBox(key: Key('profile-destination'))),
        ),
        GoRoute(
          path: '/support',
          builder: (BuildContext context, GoRouterState state) =>
              const Scaffold(body: SizedBox(key: Key('support-destination'))),
        ),
        GoRoute(
          path: '/cart',
          builder: (BuildContext context, GoRouterState state) =>
              const SizedBox.shrink(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedInRepository()),
        ],
        child: MaterialApp.router(
          locale: const Locale('ar'),
          supportedLocales: const <Locale>[Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Map<Key, Key> destinations = <Key, Key>{
      const Key('account-action-orders'): const Key('orders-destination'),
      const Key('account-action-addresses'): const Key('addresses-destination'),
      const Key('account-action-profile'): const Key('profile-destination'),
      const Key('account-action-support'): const Key('support-destination'),
    };
    for (final MapEntry<Key, Key> destination in destinations.entries) {
      router.go('/account');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(destination.key));
      await tester.pumpAndSettle();
      expect(find.byKey(destination.value), findsOneWidget);
    }
    expect(find.textContaining('الخطوة التالية'), findsNothing);
  });
}

class _SignedOutRepository implements AuthRepository {
  @override
  Future<Uri> beginSocialSignIn({
    required SocialAuthProvider provider,
    required String returnPath,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<SocialAuthCompletion> completeSocialSignIn({
    required String code,
    required String state,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthIdentity> identify(String email) async {
    return AuthIdentity(email: email, isRegistered: false);
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AuthSession?> restoreSession() async => null;

  @override
  Future<void> signOut(AuthSession session) async {}
}

class _SignedInRepository extends _SignedOutRepository {
  _SignedInRepository([this.email = 'customer@example.com']);
  final String email;
  @override
  Future<AuthSession?> restoreSession() async {
    return AuthSession(
      token: 'session-token',
      expiresAt: DateTime.utc(2099),
      user: AuthUser(id: 7, email: email, displayName: 'Customer'),
    );
  }
}
