import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/core/app_design/application_identity_provider58.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/data/website_auth_service.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/native_auth.dart';
import 'package:mobishop_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobishop_store_app/features/auth/presentation/auth_screen.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/native_auth_providers.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

AuthSession _session() => AuthSession(
  token: 'synthetic-facebook-screen-session',
  expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
  user: const AuthUser(id: 7, email: 'fixture@example.com'),
);

AuthRepositoryException _error(String code) => AuthRepositoryException(
  kind: code == 'mobishop_native_account_conflict'
      ? AuthFailureKind.conflict
      : AuthFailureKind.configuration,
  code: code,
  message: 'Synthetic sign-in failure.',
);

void main() {
  for (final conflict in [false, true]) {
    testWidgets(
      'Facebook phone enrollment replaces previous email identity conflict=$conflict',
      (tester) async {
        final fixture = _Fixture();
        fixture.actions.enrollment = true;
        fixture.actions.conflict = conflict;
        await fixture.pump(tester);
        await tester.enterText(
          find.byKey(const Key('auth-email')),
          'existing@example.invalid',
        );
        await _tapKey(tester, 'auth-continue');
        expect(find.byKey(const Key('auth-sign-in')), findsOneWidget);
        await _tapFacebook(tester);
        await tester.enterText(
          find.byKey(const Key('auth-phone')),
          '01012345678',
        );
        await _tapKey(tester, 'auth-send-otp');
        expect(fixture.actions.prepares, 1);
        if (conflict) {
          expect(
            find.byKey(const Key('auth-existing-phone-signin')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('auth-different-phone')), findsOneWidget);
          expect(fixture.actions.confirms, 0);
          expect(fixture.actions.commits, 0);
        } else {
          await tester.enterText(
            find.byKey(const Key('auth-phone')),
            '01012345678',
          );
          await _tapKey(tester, 'auth-send-otp');
          expect(fixture.actions.confirms, 1);
          expect(fixture.actions.commits, 0);
          await tester.enterText(
            find.byKey(const Key('auth-name')),
            'New Fixture',
          );
          await tester.enterText(
            find.byKey(const Key('auth-create-password')),
            'fixture-password',
          );
          await tester.enterText(
            find.byKey(const Key('auth-confirm-password')),
            'fixture-password',
          );
          await _tapKey(tester, 'auth-register');
          expect(fixture.actions.registrations, 1);
          expect(fixture.actions.commits, 1);
          expect(find.text('SIGNED IN'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final websiteEnabled in [false, true]) {
      testWidgets(
        'Facebook $platform selects native with website enabled=$websiteEnabled',
        (tester) async {
          final fixture = _Fixture(websiteEnabled: websiteEnabled);
          await fixture.pump(tester);
          await _tapFacebook(tester);
          expect(fixture.actions.facebookCalls, 1);
          expect(fixture.actions.commits, 1);
          expect(fixture.auth.websiteProviders, isEmpty);
          expect(find.text('SIGNED IN'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }

  testWidgets(
    'Missing compiled Facebook identity uses the enabled website fallback once',
    (tester) async {
      final fixture = _Fixture();
      fixture.actions.issue = () async =>
          throw _error('facebook-native-registration-required');
      await fixture.pump(tester);
      await _tapFacebook(tester);
      expect(fixture.actions.facebookCalls, 1);
      expect(fixture.actions.commits, 0);
      expect(fixture.auth.websiteProviders, ['facebook']);
      expect(fixture.auth.websiteAttempts, hasLength(1));
      expect(fixture.auth.websiteAttempts.single, isNotNull);
      expect(find.text('SIGNED IN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final code in [
    'cancelled',
    'mobishop_native_account_conflict',
    'invalid-facebook-proof',
    'mobishop_native_invalid_proof',
  ]) {
    testWidgets('Facebook $code never downgrades to website authentication', (
      tester,
    ) async {
      final fixture = _Fixture();
      fixture.actions.issue = () async => throw _error(code);
      await fixture.pump(tester);
      await _tapFacebook(tester);
      expect(fixture.actions.facebookCalls, 1);
      expect(fixture.actions.commits, 0);
      expect(fixture.auth.websiteProviders, isEmpty);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.byKey(const Key('auth-error')), findsOneWidget);
      expect(find.text('SIGNED IN'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Missing compiled Facebook identity cannot enable a disabled website fallback',
    (tester) async {
      final fixture = _Fixture(websiteEnabled: false);
      fixture.actions.issue = () async =>
          throw _error('facebook-native-registration-required');
      await fixture.pump(tester);
      await _tapFacebook(tester);
      expect(fixture.actions.facebookCalls, 1);
      expect(fixture.actions.commits, 0);
      expect(fixture.auth.websiteProviders, isEmpty);
      expect(find.byKey(const Key('auth-error')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Website-only Facebook configuration preserves the existing website path',
    (tester) async {
      final fixture = _Fixture(nativeEnabled: false);
      await fixture.pump(tester);
      await _tapFacebook(tester);
      expect(fixture.actions.facebookCalls, 0);
      expect(fixture.actions.commits, 0);
      expect(fixture.auth.websiteProviders, ['facebook']);
      expect(find.text('SIGNED IN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Late local readiness failure after closing cannot open website authentication',
    (tester) async {
      final fixture = _Fixture();
      final pending = Completer<NativeAuthResult>();
      fixture.actions.issue = () => pending.future;
      await fixture.pump(tester);
      await _tapFacebook(tester, settle: false);
      expect(fixture.actions.facebookCalls, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      pending.completeError(_error('facebook-native-registration-required'));
      await tester.pumpAndSettle();
      expect(fixture.auth.websiteProviders, isEmpty);
      expect(fixture.actions.commits, 0);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _tapFacebook(WidgetTester tester, {bool settle = true}) async {
  final button = find.byKey(const Key('auth-facebook'));
  await tester.ensureVisible(button);
  await tester.pump();
  await tester.tap(button);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final button = find.byKey(Key(key));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

class _Fixture {
  _Fixture({bool nativeEnabled = true, bool websiteEnabled = true})
    : configuration = NativeAuthConfig(
        supportsUnverifiedPhoneEnrollment: true,
        phoneCountryCode: '20',
        methods: {
          'email_password': true,
          'facebook_native': nativeEnabled,
          'facebook': websiteEnabled,
        },
      );

  final NativeAuthConfig configuration;
  final actions = _Actions();
  final auth = _Controller();

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    actions.onCommit = auth.publish;
    final router = GoRouter(
      initialLocation: '/auth',
      routes: [
        GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
        GoRoute(
          path: '/account',
          builder: (_, _) => const Scaffold(body: Text('SIGNED IN')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => auth),
          lastLoginMethodProvider.overrideWith((_) async => null),
          nativeAuthActionsProvider.overrideWithValue(actions),
          nativeAuthConfigProvider.overrideWith((_) async => configuration),
          applicationIdentity58Provider.overrideWithValue({
            'app_name': 'Fixture Store',
          }),
          cmsPageLayoutProvider('account').overrideWith(
            (_) async => CmsPageLayout.fromJson({'page': 'account'}),
          ),
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

class _Actions
    implements
        NativeAuthActions,
        NativeFacebookAuthActions,
        NativePhoneEnrollmentActions {
  bool enrollment = false;
  bool conflict = false;
  int prepares = 0;
  int confirms = 0;
  @override
  Future<NativeAuthIdentity> identify(String identifier) async =>
      NativeAuthIdentity(
        identifier: identifier,
        kind: 'email',
        methods: ['password'],
      );
  @override
  Future<NativeAuthResult> preparePhone(String phone, {String? ticket}) async {
    prepares++;
    if (conflict) throw _error('mobishop_native_existing_phone');
    expect(ticket, 'facebook-enrollment');
    return const NativeAuthResult(
      status: NativeAuthStatus.registrationRequired,
      ticket: 'prepared-phone',
      fields: ['phone'],
      expiresIn: 300,
    );
  }

  @override
  Future<NativeOtpChallenge> sendOtp(
    String phone, {
    NativeOtpChallenge? resend,
    String? ticket,
  }) async => throw _error('unavailable');
  @override
  Future<NativeAuthResult> confirmUnverifiedPhone(
    String ticket,
    String phone,
  ) async {
    confirms++;
    expect(ticket, 'prepared-phone');
    return const NativeAuthResult(
      status: NativeAuthStatus.registrationRequired,
      ticket: 'confirmed-contact',
      fields: ['name', 'password'],
      expiresIn: 300,
    );
  }

  int registrations = 0;
  @override
  Future<NativeAuthResult> register(
    String ticket, {
    required String name,
    required String password,
    String? email,
  }) async {
    expect(ticket, 'confirmed-contact');
    expect(name, 'New Fixture');
    expect(password, 'fixture-password');
    registrations++;
    return NativeAuthResult(
      status: NativeAuthStatus.authenticated,
      session: _session(),
    );
  }

  int facebookCalls = 0;
  int commits = 0;
  void Function(AuthSession)? onCommit;
  Future<NativeAuthResult> Function() issue = () async => NativeAuthResult(
    status: NativeAuthStatus.authenticated,
    session: _session(),
  );

  @override
  Future<NativeAuthResult> facebook() {
    facebookCalls++;
    if (enrollment) {
      return Future.value(
        const NativeAuthResult(
          status: NativeAuthStatus.registrationRequired,
          ticket: 'facebook-enrollment',
          fields: ['phone'],
          expiresIn: 300,
        ),
      );
    }
    return issue();
  }

  @override
  Future<AuthSession> commit(NativeAuthResult result) async {
    commits++;
    onCommit?.call(result.session!);
    return result.session!;
  }

  @override
  Future<void> cancel() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Controller extends AuthController {
  final websiteProviders = <String?>[];
  final websiteAttempts = <WebsiteAuthAttempt?>[];
  @override
  Future<AuthSession?> build() async => null;
  void publish(AuthSession session) => state = AsyncData(session);

  @override
  Future<AuthSession> signInThroughWebsite({
    String? provider,
    WebsiteAuthBrowser? presenter,
    WebsiteAuthAttempt? attempt,
  }) async {
    websiteProviders.add(provider);
    websiteAttempts.add(attempt);
    attempt?.checkActive();
    final session = _session();
    publish(session);
    return session;
  }
}
