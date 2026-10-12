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

void main() {
  for(final selected in ['orders','addresses','profile','support']) {
    testWidgets('account menu shows only the configured action: $selected', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390,844));
      addTearDown(()=>tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ProviderScope(overrides:[
        authRepositoryProvider.overrideWithValue(_SignedOutRepository()),
        cmsPageLayoutProvider('account').overrideWith((ref) async=>CmsPageLayout.fromJson({
          'page':'account','header':{'enabled':false},'footer':{'enabled':false},
          'elements':[
            {'id':'account_summary','enabled':true,'settings':{'guest_title':'عنوان الدخول المخصص','avatar_size':40,'card_style':'minimal'}},
            {'id':'account_menu','enabled':true,'settings':{
              for(final action in ['orders','addresses','profile','support']) 'show_$action':action==selected,
            }},
            {'id':'logout_button','enabled':true},
          ],
        })),
      ],child:MaterialApp(locale:const Locale('ar'),supportedLocales:const[Locale('ar')],
        localizationsDelegates:GlobalMaterialLocalizations.delegates,home:const AccountScreen())));
      await tester.pumpAndSettle();
      for(final action in ['orders','addresses','profile','support']) {
        expect(find.byKey(Key('account-action-$action')),action==selected?findsOneWidget:findsNothing);
      }
      expect(find.text('عنوان الدخول المخصص'),findsOneWidget);
      expect(find.byKey(const Key('account-sign-out')),findsNothing);
      final card=tester.widget<Card>(find.byType(Card).first);
      expect(card.elevation,0);
      expect((card.shape! as RoundedRectangleBorder).side,BorderSide.none);
      expect(Directionality.of(tester.element(find.byType(AccountScreen))),TextDirection.rtl);
      expect(tester.takeException(),isNull);
    });
  }

  for (final visible in <bool>[false, true]) {
    testWidgets('saved account email/logout and avatar settings: $visible', (tester) async {
      final avatar = visible ? 90.0 : 40.0;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_SignedInRepository()),
          cmsPageLayoutProvider('account').overrideWith((ref) async => CmsPageLayout.fromJson({
            'page': 'account',
            'header': {'enabled': false}, 'footer': {'enabled': false},
            'elements': [
              {'id': 'account_summary', 'enabled': true, 'settings': {
                'show_email': visible, 'avatar_size': avatar, 'card_style': 'outlined',
              }},
              {'id': 'account_menu', 'enabled': false},
              {'id': 'logout_button', 'enabled': visible},
            ],
          })),
        ],
        child: const MaterialApp(home: AccountScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('customer@example.com'), visible ? findsOneWidget : findsNothing);
      expect(find.byKey(const Key('account-sign-out')), visible ? findsOneWidget : findsNothing);
      expect(find.byKey(const Key('account-action-orders')), findsNothing);
      final avatarBox = find.ancestor(of: find.byIcon(Icons.person_rounded), matching: find.byType(Container)).first;
      expect(tester.getSize(avatarBox), Size(avatar, avatar));
      final card = tester.widget<Card>(find.byType(Card).first);
      expect((card.shape! as RoundedRectangleBorder).side.style, BorderStyle.solid);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('preview account uses the selected application name', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(_SignedOutRepository()),
        previewIdentityProvider.overrideWith((ref) => Stream.value({'app_name': 'كيديا ستور'})),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const AccountScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('تابع طلباتك وبياناتك على كيديا ستور'), findsOneWidget);
  }, skip: !AppConfig.isCmsPreview);

  testWidgets('every signed-out account action opens the same auth screen', (
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
      const Key('account-action-support'),
    ];
    for (final Key key in entryPoints) {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
      expect(find.byType(AuthScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('auth-close')));
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsOneWidget);
    }
  });

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
  @override
  Future<AuthSession?> restoreSession() async {
    return AuthSession(
      token: 'session-token',
      expiresAt: DateTime.utc(2099),
      user: const AuthUser(
        id: 7,
        email: 'customer@example.com',
        displayName: 'Customer',
      ),
    );
  }
}
