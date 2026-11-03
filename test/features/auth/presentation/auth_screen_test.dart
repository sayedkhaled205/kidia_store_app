import 'package:mobishop_store_app/features/auth/data/storage/last_login_method_store.dart';
import '../../../support/viewport_rotation.dart';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/core/app_design/application_identity_provider58.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/data/cms_preview_auth_actions.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/native_auth.dart';
import 'package:mobishop_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobishop_store_app/features/auth/presentation/auth_screen.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/native_auth_providers.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/shared/widgets/common/app_network_image.dart';

void main() {
  testWidgets(
    'Apple shown on iOS only and name-only registration has no password step',
    (tester) async {
      final actions = _Actions()
        ..configuration = const NativeAuthConfig(methods: {'apple': true});
      await _Fixture(
        actions: actions,
      ).pump(tester, lastLogin: LastLoginMethod.apple);
      expect(find.byKey(const Key('auth-apple')), findsOneWidget);
      await _tap(tester, 'auth-apple');
      expect(find.byKey(const Key('auth-create-password')), findsNothing);
      expect(find.byKey(const Key('auth-confirm-password')), findsNothing);
      expect(actions.googleCalls, 0);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  testWidgets('Android never offers Apple from a misconfigured server', (
    tester,
  ) async {
    final actions = _Actions()
      ..configuration = const NativeAuthConfig(
        methods: {'email_password': true, 'apple': true},
      );
    await _Fixture(actions: actions).pump(tester);
    expect(find.byKey(const Key('auth-apple')), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  testWidgets('equal social circles and last successful method hint', (
    tester,
  ) async {
    final actions = _Actions()
      ..configuration = const NativeAuthConfig(
        methods: {'email_password': true, 'google': true, 'facebook': true},
      );
    await _Fixture(
      actions: actions,
    ).pump(tester, lastLogin: LastLoginMethod.google);
    expect(find.byKey(const Key('auth-last-login')), findsOneWidget);
    expect(find.text('آخر تسجيل دخول'), findsOneWidget);
    for (final key in ['auth-google', 'auth-facebook']) {
      final button = tester.widget<OutlinedButton>(find.byKey(Key(key)));
      expect(button.style!.visualDensity, VisualDensity.standard);
      expect(button.style!.fixedSize!.resolve({}), const Size.square(52));
    }
    expect(
      tester.getSize(find.byKey(const Key('auth-google'))),
      tester.getSize(find.byKey(const Key('auth-facebook'))),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('hidden method has no hint and phone hint stays by continue', (
    tester,
  ) async {
    await _Fixture().pump(tester, lastLogin: LastLoginMethod.facebook);
    expect(find.byKey(const Key('auth-last-login')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await _Fixture().pump(tester, lastLogin: LastLoginMethod.phone);
    expect(find.text('آخر تسجيل دخول · الموبايل'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preview shows configured Facebook without starting authentication',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(
        tester,
        previewActions: CmsPreviewAuthActions(
          () async => {
            'version': 1,
            'enabled': true,
            'methods': {
              'email_password': true,
              'google': true,
              'facebook': true,
            },
          },
          isArabic: true,
        ),
      );
      expect(find.byKey(const Key('auth-facebook')), findsOneWidget);
      expect(find.byKey(const Key('auth-google')), findsOneWidget);
      await _tap(tester, 'auth-facebook');
      expect(find.textContaining('دي معاينة'), findsOneWidget);
      expect(fixture.actions.commits, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'old connector keeps ordinary Google but never claims phone-bound Google support',
    (tester) async {
      final actions = _Actions()
        ..configuration = const NativeAuthConfig(
          methods: {'phone_password': true, 'phone_otp': true, 'google': true},
        );
      await _Fixture(actions: actions).pump(tester);
      expect(find.byKey(const Key('auth-google')), findsOneWidget);
      await _identify(tester, '+201012345678');
      expect(find.byKey(const Key('auth-use-password')), findsOneWidget);
      expect(find.byKey(const Key('auth-use-otp')), findsOneWidget);
      expect(find.byKey(const Key('auth-google')), findsNothing);
    },
  );
  testWidgets(
    'asynchronous send failure repeats new contact without error banner',
    (tester) async {
      final automatic = Completer<NativeAuthResult?>();
      final actions = _EnrollmentActions()
        ..identityMethods = ['phone_otp']
        ..automaticResults.add(automatic.future);
      await _Fixture(actions: actions).pump(tester);
      await _identify(tester, '+201012345678');
      automatic.completeError(
        const AuthRepositoryException(
          kind: AuthFailureKind.rateLimited,
          code: 'quota-exceeded',
          message: 'SMS unavailable',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('auth-phone')), findsOneWidget);
      expect(find.byKey(const Key('auth-error')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('auth-phone')),
        '01012345678',
      );
      await _tap(tester, 'auth-send-otp');
      expect(actions.confirmCalls, 1);
      expect(actions.commits, 0);
    },
  );

  testWidgets('wrong OTP never enables unverified contact confirmation', (
    tester,
  ) async {
    final actions = _EnrollmentActions()
      ..identityMethods = ['phone_otp']
      ..verifyError = const AuthRepositoryException(
        kind: AuthFailureKind.unauthorized,
        code: 'invalid-verification-code',
        message: 'Wrong code',
      );
    await _Fixture(actions: actions).pump(tester);
    await _identify(tester, '+201012345678');
    await tester.enterText(find.byKey(const Key('auth-otp')), '123456');
    await _tap(tester, 'auth-verify-otp');
    expect(find.byKey(const Key('auth-phone')), findsNothing);
    expect(find.byKey(const Key('auth-retry-otp')), findsOneWidget);
    expect(actions.confirmCalls, 0);
    expect(actions.commits, 0);
  });

  testWidgets(
    'mismatched Google existing phone remains at sign-in methods without commit',
    (tester) async {
      final actions = _Actions()
        ..googleError = const AuthRepositoryException(
          kind: AuthFailureKind.unauthorized,
          code: 'mobishop_native_google_phone_mismatch',
          message: 'جرّب حساب جوجل تاني أو الباسورد.',
        );
      await _Fixture(actions: actions).pump(tester);
      await _identify(tester, '+201012345678');
      await _tap(tester, 'auth-google');
      expect(actions.expectedGooglePhone, '+201012345678');
      expect(actions.commits, 0);
      expect(actions.registrationTicket, isNull);
      expect(find.byKey(const Key('auth-use-password')), findsOneWidget);
      expect(find.byKey(const Key('auth-google')), findsOneWidget);
    },
  );
  testWidgets('existing account method choices honor disabled OTP and Google', (
    tester,
  ) async {
    final actions = _Actions()
      ..configuration = const NativeAuthConfig(
        methods: {
          'password': true,
          'phone_password': true,
          'phone_otp': false,
          'google': false,
        },
      );
    await _Fixture(actions: actions).pump(tester);
    await _identify(tester, '+201012345678');
    expect(find.byKey(const Key('auth-use-password')), findsOneWidget);
    expect(find.byKey(const Key('auth-use-otp')), findsNothing);
    expect(find.byKey(const Key('auth-google')), findsNothing);
  });
  testWidgets(
    'older connector without enrollment capability keeps new phone OTP',
    (tester) async {
      final actions = _EnrollmentActions(supported: false)
        ..identityMethods = ['phone_otp'];
      await _Fixture(actions: actions).pump(tester);
      await _identify(tester, '+201012345678');
      expect(actions.prepareCalls, 0);
      expect(actions.confirmCalls, 0);
      expect(actions.sentPhones, ['+201012345678']);
      expect(find.byKey(const Key('auth-otp')), findsOneWidget);
    },
  );
  testWidgets('existing phone OTP failure never offers unverified enrollment', (
    tester,
  ) async {
    final actions = _EnrollmentActions()
      ..sendError = StateError('SMS unavailable');
    await _Fixture(actions: actions).pump(tester);
    await _startOtp(tester);
    expect(actions.prepareCalls, 0);
    expect(actions.confirmCalls, 0);
    expect(find.byKey(const Key('auth-phone')), findsNothing);
    expect(find.byKey(const Key('auth-use-password')), findsOneWidget);
    expect(actions.commits, 0);
  });

  testWidgets(
    'new phone send failure repeats contact before profile, without committing',
    (tester) async {
      final actions = _EnrollmentActions()
        ..identityMethods = ['phone_otp']
        ..sendError = StateError('SMS unavailable');
      final fixture = _Fixture(actions: actions);
      await fixture.pump(tester);
      await _identify(tester, '+201012345678');
      expect(actions.prepareCalls, 1);
      expect(actions.commits, 0);
      expect(find.byKey(const Key('auth-phone')), findsOneWidget);
      expect(find.text('اكتب رقم موبايلك مرة كمان للمتابعة'), findsOneWidget);
      expect(find.byKey(const Key('auth-error')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('auth-phone')),
        '01012345678',
      );
      await _tap(tester, 'auth-send-otp');
      expect(actions.confirmCalls, 1);
      expect(actions.sentPhones.length, 1);
      expect(find.byKey(const Key('auth-name')), findsOneWidget);
      expect(actions.commits, 0);
    },
  );

  testWidgets('different number after send failure starts a new OTP attempt', (
    tester,
  ) async {
    final actions = _EnrollmentActions()
      ..identityMethods = ['phone_otp']
      ..sendError = StateError('SMS unavailable');
    await _Fixture(actions: actions).pump(tester);
    await _identify(tester, '01012345678');
    actions.sendError = null;
    await tester.enterText(find.byKey(const Key('auth-phone')), '01112345678');
    await _tap(tester, 'auth-send-otp');
    expect(actions.prepareCalls, 2);
    expect(actions.confirmCalls, 0);
    expect(find.byKey(const Key('auth-otp')), findsOneWidget);
  });

  testWidgets(
    'existing enrollment phone offers sign-in methods and a different number',
    (tester) async {
      final actions = _EnrollmentActions()
        ..identityMethods = ['phone_otp']
        ..prepareError = const AuthRepositoryException(
          kind: AuthFailureKind.conflict,
          message: 'Existing phone',
          code: 'mobishop_native_existing_phone',
        );
      await _Fixture(actions: actions).pump(tester);
      await _identify(tester, '01012345678');
      expect(actions.sentPhones, isEmpty);
      expect(find.byKey(const Key('auth-different-phone')), findsOneWidget);
      expect(find.byKey(const Key('auth-send-otp')), findsNothing);
      expect(find.text('الدخول للحساب الموجود'), findsOneWidget);
      expect(find.byKey(const Key('auth-phone')), findsNothing);
      expect(find.text('01012345678'), findsOneWidget);
      final card = tester.getRect(
        find.byKey(const Key('auth-existing-account-card')),
      );
      final signIn = tester.getRect(
        find.byKey(const Key('auth-existing-phone-signin')),
      );
      final change = tester.getRect(
        find.byKey(const Key('auth-different-phone')),
      );
      expect(signIn.top - card.bottom, greaterThanOrEqualTo(24));
      expect(change.top - signIn.bottom, greaterThanOrEqualTo(12));
      actions.identityMethods = ['password', 'phone_otp'];
      await _tap(tester, 'auth-existing-phone-signin');
      expect(find.byKey(const Key('auth-use-password')), findsOneWidget);
      expect(find.byKey(const Key('auth-use-otp')), findsOneWidget);
      expect(find.byKey(const Key('auth-google')), findsOneWidget);
      await _tap(tester, 'auth-use-password');
      expect(find.byKey(const Key('auth-password')), findsOneWidget);
      expect(actions.commits, 0);
    },
  );

  testWidgets(
    'existing account send failure shows only enabled password and Google fallbacks',
    (tester) async {
      final actions = _Actions()..sendError = StateError('SMS unavailable');
      await _Fixture(actions: actions).pump(tester);
      await _startOtp(tester);
      expect(
        find.text('تعذر إرسال رمز التحقق. اختار طريقة تانية للدخول.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('auth-use-password')), findsOneWidget);
      expect(find.byKey(const Key('auth-google')), findsOneWidget);
      expect(find.byKey(const Key('auth-retry-otp')), findsNothing);
      expect(find.byKey(const Key('auth-use-otp')), findsNothing);
      await _tap(tester, 'auth-use-password');
      expect(find.byKey(const Key('auth-use-otp')), findsNothing);
      expect(actions.commits, 0);
    },
  );

  testWidgets(
    'disabled Google stays hidden after an existing account send failure',
    (tester) async {
      final actions = _Actions()
        ..sendError = StateError('SMS unavailable')
        ..configuration = const NativeAuthConfig(
          methods: {'phone_password': true, 'phone_otp': true, 'google': false},
        );
      await _Fixture(actions: actions).pump(tester);
      await _startOtp(tester);
      expect(find.byKey(const Key('auth-use-password')), findsOneWidget);
      expect(find.byKey(const Key('auth-google')), findsNothing);
      expect(find.byKey(const Key('auth-retry-otp')), findsNothing);
    },
  );

  testWidgets(
    'existing enrollment sign-in uses a fresh Google proof without registration or phone linking',
    (tester) async {
      final actions = _EnrollmentActions()
        ..identityMethods = ['phone_otp']
        ..prepareError = const AuthRepositoryException(
          kind: AuthFailureKind.conflict,
          message: 'Existing phone',
          code: 'mobishop_native_existing_phone',
        );
      await _Fixture(actions: actions).pump(tester);
      await _identify(tester, '+201012345678');
      actions.identityMethods = ['password', 'phone_otp'];
      await _tap(tester, 'auth-existing-phone-signin');
      await _tap(tester, 'auth-google');
      expect(actions.googleCalls, 1);
      expect(actions.commits, 1);
      expect(actions.passwordCalls, 0);
      expect(actions.verifyTicket, isNull);
      expect(actions.registrationTicket, isNull);
    },
  );

  viewportRotationTests(
    'Sign in',
    (tester, size) => _Fixture().pump(tester, size: size),
  );
  testWidgets(
    'first identifier field shows the local phone example in gray without restricting email',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      final field = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('auth-email')),
          matching: find.byType(TextField),
        ),
      );
      expect(field.decoration!.hintText, '01XXXXXXXXX');
      expect(field.decoration!.hintStyle!.color, const Color(0xFF9E9E9E));
      expect(
        field.decoration!.floatingLabelBehavior,
        FloatingLabelBehavior.always,
      );
      await tester.enterText(
        find.byKey(const Key('auth-email')),
        'customer@example.com',
      );
      await _tap(tester, 'auth-continue');
      expect(fixture.actions.identifiers, ['customer@example.com']);
    },
  );

  testWidgets('Google sign-in keeps a bundled full-color mark without tinting', (
    tester,
  ) async {
    await _Fixture().pump(tester);
    final image = tester.widget<Image>(
      find.byKey(const Key('auth-google-brand')),
    );
    expect(image.image, const AssetImage('assets/branding/google-g.png'));
    expect(image.color, isNull);
    expect(image.fit, BoxFit.contain);
    expect(image.width, 24);
    expect(image.height, 24);
    expect(
      find.descendant(
        of: find.byKey(const Key('auth-google')),
        matching: find.text('G'),
      ),
      findsNothing,
    );
    // Check the actual packaged pixels, so a missing or monochrome replacement
    // also fails even when the widget and asset name have stayed unchanged.
    await tester.runAsync(() async {
      final data = await rootBundle.load('assets/branding/google-g.png');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final pixels = (await frame.image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final colors = <String>{};
      for (var i = 0; i < pixels.lengthInBytes; i += 4) {
        if (pixels.getUint8(i + 3) < 240) continue;
        final r = pixels.getUint8(i),
            g = pixels.getUint8(i + 1),
            b = pixels.getUint8(i + 2);
        if (r > 180 && g < 130 && b < 130) colors.add('red');
        if (r > 180 && g > 150 && b < 100) colors.add('yellow');
        if (g > 120 && r < 100 && b < 150) colors.add('green');
        if (b > 180 && r < 130 && g < 180) colors.add('blue');
      }
      frame.image.dispose();
      codec.dispose();
      expect(colors, containsAll(['red', 'yellow', 'green', 'blue']));
    });
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'CMS preview refreshes Google availability after short public cache expires',
    (tester) async {
      var googleEnabled = true;
      var requests = 0;
      final preview = CmsPreviewAuthActions(() async {
        requests++;
        return {
          'version': 1,
          'enabled': true,
          'methods': {
            'email_password': true,
            'phone_otp': true,
            'google': googleEnabled,
          },
        };
      }, isArabic: true);
      final fixture = _Fixture();
      await fixture.pump(tester, previewActions: preview);
      expect(find.byKey(const Key('auth-google')), findsOneWidget);
      await _tap(tester, 'auth-google');
      expect(find.textContaining('دي معاينة لشاشة الدخول'), findsOneWidget);
      expect(find.byKey(const Key('auth-google')), findsOneWidget);
      for (final enabled in [false, true]) {
        fixture.router.go('/account');
        await tester.pumpAndSettle();
        googleEnabled = enabled;
        await tester.pump(const Duration(seconds: 31));
        fixture.router.go('/auth');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('auth-google')),
          enabled ? findsOneWidget : findsNothing,
        );
      }
      expect(requests, 3);
      expect(fixture.actions.commits, 0);
    },
  );

  testWidgets('CMS preview can retry unavailable settings and restore Google', (
    tester,
  ) async {
    var available = false;
    final fixture = _Fixture();
    await fixture.pump(
      tester,
      previewActions: CmsPreviewAuthActions(() async {
        if (!available) throw StateError('offline');
        return {
          'version': 1,
          'enabled': true,
          'methods': {'email_password': true, 'google': true},
        };
      }, isArabic: true),
    );
    expect(find.byKey(const Key('auth-config-retry')), findsOneWidget);
    available = true;
    await _tap(tester, 'auth-config-retry');
    expect(find.byKey(const Key('auth-google')), findsOneWidget);
    expect(find.byKey(const Key('auth-config-retry')), findsNothing);
  });

  testWidgets(
    'native phone/email screen has one close, real brand and enabled Google only',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('متجر الاختبار'), findsOneWidget);
      expect(find.text('رقم الموبايل أو البريد الإلكتروني'), findsOneWidget);
      expect(find.byKey(const Key('auth-google')), findsOneWidget);
      expect(find.byKey(const Key('auth-facebook')), findsNothing);
      expect(find.byKey(const Key('website-auth-browser')), findsNothing);
      expect(
        tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
        Colors.white,
      );
      expect(fixture.actions.commits, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Kids sign-in logo is ten percent smaller without distortion', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.pump(
      tester,
      logo: 'https://store.example/logo.png',
      logoScale: 0.9,
    );
    final image = tester.widget<AppNetworkImage>(
      find.byKey(const Key('auth-store-logo')),
    );
    expect(image.width, 198);
    expect(image.height, closeTo(57.6, 0.001));
    expect(image.fit, BoxFit.contain);
  });

  testWidgets('capabilities hide unsupported phone and Google methods', (
    tester,
  ) async {
    final fixture = _Fixture()
      ..actions.configuration = const NativeAuthConfig(
        methods: {'email_password': true},
      );
    await fixture.pump(tester);
    expect(find.text('البريد الإلكتروني'), findsOneWidget);
    expect(find.byKey(const Key('auth-google')), findsNothing);
    await _identify(tester, '01012345678');
    expect(fixture.actions.identifiers, isEmpty);
  });

  testWidgets('wide brand logo uses contain and a name fallback', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.pump(tester, logo: 'https://store.example/logo.png');
    final image = tester.widget<AppNetworkImage>(
      find.byKey(const Key('auth-store-logo')),
    );
    expect(image.fit, BoxFit.contain);
    expect(image.errorWidget, isNotNull);
    expect(image.placeholder, isNotNull);
  });

  testWidgets(
    'Google-only capabilities do not expose unsupported email input',
    (tester) async {
      final fixture = _Fixture()
        ..actions.configuration = const NativeAuthConfig(
          methods: {'google': true},
        );
      await fixture.pump(tester);
      expect(find.byKey(const Key('auth-email')), findsNothing);
      expect(find.byKey(const Key('auth-continue')), findsNothing);
      expect(find.byKey(const Key('auth-google')), findsOneWidget);
    },
  );

  for (final route in [
    '/auth',
    '/checkout?step=delivery&coupon=SAVE',
    '/orders?status=paid',
    '/profile?from=account',
  ]) {
    testWidgets(
      'native password commits once and preserves destination $route',
      (tester) async {
        final fixture = _Fixture();
        await fixture.pump(tester, route: route);
        await _identify(tester, 'customer@example.com');
        expect(find.byKey(const Key('auth-password')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('auth-password')),
          'valid-password',
        );
        await _tap(tester, 'auth-sign-in');
        expect(fixture.actions.passwordCalls, 1);
        expect(fixture.actions.commits, 1);
        expect(
          fixture.router.routeInformationProvider.value.uri.toString(),
          route == '/auth' ? '/account' : route,
        );
        expect(find.text('CUSTOMER 7'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'phone identity offers password and OTP without disclosing accounts',
    (tester) async {
      final fixture = _Fixture();
      await fixture.pump(tester);
      await _identify(tester, '٠١٠١٢٣٤٥٦٧٨');
      expect(fixture.actions.identifiers.single, '01012345678');
      expect(find.byKey(const Key('auth-use-password')), findsOneWidget);
      expect(find.byKey(const Key('auth-use-otp')), findsOneWidget);
      expect(find.byKey(const Key('auth-account-9')), findsNothing);
      await _tap(tester, 'auth-use-password');
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'valid-password',
      );
      await _tap(tester, 'auth-sign-in');
      expect(fixture.actions.commits, 1);
    },
  );

  testWidgets(
    'verified OTP reveals account chooser and only selected account is committed',
    (tester) async {
      final fixture = _Fixture()
        ..actions.verifyResult = const NativeAuthResult(
          status: NativeAuthStatus.selectAccount,
          ticket: 'verified-ticket',
          expiresIn: 300,
          accounts: [
            NativeAuthAccount(
              id: 9,
              name: 'الحساب الأول',
              emailHint: 'o***@example.com',
            ),
            NativeAuthAccount(id: 12, name: 'الحساب الثاني'),
          ],
        );
      await fixture.pump(tester);
      await _startOtp(tester);
      expect(find.text('الحساب الأول'), findsNothing);
      await tester.enterText(find.byKey(const Key('auth-otp')), '123456');
      await _tap(tester, 'auth-verify-otp');
      expect(find.text('الحساب الأول'), findsOneWidget);
      expect(find.byKey(const Key('auth-account-12')), findsOneWidget);
      expect(fixture.actions.commits, 0);
      await _tap(tester, 'auth-account-12');
      expect(fixture.actions.selectedAccount, 12);
      expect(fixture.actions.selectionTicket, 'verified-ticket');
      expect(fixture.actions.commits, 1);
    },
  );

  testWidgets('automatic OTP wins once over a late manual verification', (
    tester,
  ) async {
    final automatic = Completer<NativeAuthResult?>();
    final manual = Completer<NativeAuthResult>();
    final fixture = _Fixture();
    fixture.actions.automaticResults.add(automatic.future);
    fixture.actions.verifyFuture = manual.future;
    await fixture.pump(tester);
    await _startOtp(tester);
    await tester.enterText(find.byKey(const Key('auth-otp')), '123456');
    await _tap(tester, 'auth-verify-otp', settle: false);
    automatic.complete(_authenticated());
    await tester.pumpAndSettle();
    manual.complete(_authenticated());
    await tester.pumpAndSettle();
    expect(fixture.actions.commits, 1);
    expect(find.text('CUSTOMER 7'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('manual OTP wins once over a late automatic result', (
    tester,
  ) async {
    final automatic = Completer<NativeAuthResult?>();
    final fixture = _Fixture()..actions.automaticResults.add(automatic.future);
    await fixture.pump(tester);
    await _startOtp(tester);
    await tester.enterText(find.byKey(const Key('auth-otp')), '123456');
    await _tap(tester, 'auth-verify-otp');
    automatic.complete(_authenticated());
    await tester.pumpAndSettle();
    expect(fixture.actions.commits, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'resend invalidates old automatic result and passes previous challenge',
    (tester) async {
      final oldAutomatic = Completer<NativeAuthResult?>();
      final newAutomatic = Completer<NativeAuthResult?>();
      final fixture = _Fixture();
      fixture.actions.automaticResults.addAll([
        oldAutomatic.future,
        newAutomatic.future,
      ]);
      await fixture.pump(tester);
      await _startOtp(tester);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('auth-resend')))
            .onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 61));
      await _tap(tester, 'auth-resend');
      expect(fixture.actions.sentPhones.length, 2);
      expect(fixture.actions.resends.last, isNotNull);
      oldAutomatic.complete(_authenticated());
      await tester.pumpAndSettle();
      expect(fixture.actions.commits, 0);
      newAutomatic.complete(_authenticated());
      await tester.pumpAndSettle();
      expect(fixture.actions.commits, 1);
    },
  );

  testWidgets('Google account picker success commits through native actions', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.pump(tester);
    await _tap(tester, 'auth-google');
    expect(fixture.actions.googleCalls, 1);
    expect(fixture.actions.commits, 1);
    expect(find.text('CUSTOMER 7'), findsOneWidget);
  });

  testWidgets(
    'OTP-only identity skips method choice and invalid code can retry',
    (tester) async {
      final fixture = _Fixture()
        ..actions.identityMethods = ['phone_otp']
        ..actions.verifyError = const AuthRepositoryException(
          kind: AuthFailureKind.unauthorized,
          message: 'Invalid code',
          code: 'invalid-verification-code',
        );
      await fixture.pump(tester);
      await _identify(tester, '01012345678');
      expect(find.byKey(const Key('auth-use-password')), findsNothing);
      expect(find.byKey(const Key('auth-otp')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('auth-otp')), '123456');
      await _tap(tester, 'auth-verify-otp');
      expect(find.text('رمز التحقق غير صحيح أو انتهت صلاحيته'), findsOneWidget);
      expect(fixture.actions.commits, 0);
      expect(find.byKey(const Key('auth-otp')), findsNothing);
      expect(find.byKey(const Key('auth-google')), findsOneWidget);
      expect(find.byKey(const Key('auth-use-password')), findsNothing);
      fixture.actions.verifyError = null;
      await _tap(tester, 'auth-retry-otp');
      await tester.enterText(find.byKey(const Key('auth-otp')), '654321');
      await _tap(tester, 'auth-verify-otp');
      expect(fixture.actions.sentPhones, hasLength(1));
      expect(fixture.actions.commits, 1);
    },
  );

  testWidgets(
    'SMS send failure offers password and Google without losing checkout',
    (tester) async {
      final fixture = _Fixture()
        ..actions.sendError = const AuthRepositoryException(
          kind: AuthFailureKind.invalidInput,
          code: 'app-not-authorized',
          message: 'Verification unavailable',
        );
      await fixture.pump(
        tester,
        route: '/checkout',
        size: const Size(320, 640),
      );
      await _startOtp(tester);
      expect(find.text('اختار طريقة تانية للدخول'), findsOneWidget);
      expect(find.byKey(const Key('auth-google')), findsOneWidget);
      expect(find.byKey(const Key('auth-otp')), findsNothing);
      await _tap(tester, 'auth-use-password');
      await tester.enterText(
        find.byKey(const Key('auth-password')),
        'password',
      );
      await _tap(tester, 'auth-sign-in');
      expect(
        fixture.router.routeInformationProvider.value.uri.path,
        '/checkout',
      );
      expect(fixture.actions.commits, 1);
      expect(fixture.actions.cancelCalls, greaterThan(0));
    },
  );

  testWidgets(
    'failed automatic OTP can recover with Google and retains resend cooldown',
    (tester) async {
      final automatic = Completer<NativeAuthResult?>();
      final fixture = _Fixture()
        ..actions.automaticResults.add(automatic.future);
      await fixture.pump(tester);
      await _startOtp(tester);
      automatic.completeError(
        const AuthRepositoryException(
          kind: AuthFailureKind.server,
          message: 'Verification unavailable',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('اختار طريقة تانية للدخول'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('auth-retry-otp')))
            .onPressed,
        isNull,
      );
      await tester.pump(const Duration(seconds: 61));
      expect(
        tester
            .widget<TextButton>(find.byKey(const Key('auth-retry-otp')))
            .onPressed,
        isNotNull,
      );
      await _tap(tester, 'auth-google');
      expect(fixture.actions.commits, 1);
    },
  );

  testWidgets('cancelled Google recovery requests a fresh OTP after cooldown', (
    tester,
  ) async {
    final fixture = _Fixture()
      ..actions.verifyError = const AuthRepositoryException(
        kind: AuthFailureKind.invalidInput,
        code: 'invalid-verification-code',
        message: 'Incorrect code',
      )
      ..actions.googleError = PlatformException(code: 'sign_in_canceled');
    await fixture.pump(tester);
    await _startOtp(tester);
    await tester.enterText(find.byKey(const Key('auth-otp')), '123456');
    await _tap(tester, 'auth-verify-otp');
    await _tap(tester, 'auth-google');
    expect(find.text('اختار طريقة تانية للدخول'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('auth-retry-otp')))
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 61));
    await _tap(tester, 'auth-retry-otp');
    expect(fixture.actions.sentPhones, hasLength(2));
    expect(fixture.actions.otpTickets.last, isNull);
    expect(find.byKey(const Key('auth-otp')), findsOneWidget);
  });

  testWidgets('failed session commit retries the proven result only', (
    tester,
  ) async {
    final fixture = _Fixture()..actions.commitError = StateError('storage');
    await fixture.pump(tester);
    await _identify(tester, 'customer@example.com');
    await tester.enterText(find.byKey(const Key('auth-password')), 'password');
    await _tap(tester, 'auth-sign-in');
    expect(find.byKey(const Key('auth-error')), findsOneWidget);
    expect(fixture.actions.passwordCalls, 1);
    fixture.actions.commitError = null;
    await _tap(tester, 'auth-sign-in');
    expect(fixture.actions.passwordCalls, 1);
    expect(fixture.actions.commits, 2);
    expect(find.text('CUSTOMER 7'), findsOneWidget);
  });

  testWidgets(
    'Google registration verifies phone with ticket before collecting profile fields',
    (tester) async {
      final fixture = _Fixture();
      fixture.actions.googleResult = const NativeAuthResult(
        status: NativeAuthStatus.registrationRequired,
        ticket: 'google-ticket',
        expiresIn: 300,
        fields: ['name', 'phone', 'password'],
      );
      fixture.actions.verifyResult = const NativeAuthResult(
        status: NativeAuthStatus.registrationRequired,
        ticket: 'phone-verified-ticket',
        expiresIn: 300,
        fields: ['name', 'password'],
      );
      await fixture.pump(tester, size: const Size(320, 640));
      await _tap(tester, 'auth-google');
      expect(find.byKey(const Key('auth-name')), findsNothing);
      final phoneField = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const Key('auth-phone')),
          matching: find.byType(TextField),
        ),
      );
      expect(phoneField.decoration?.hintText, '01XXXXXXXXX');
      await tester.enterText(
        find.byKey(const Key('auth-phone')),
        '01012345678',
      );
      await _tap(tester, 'auth-send-otp');
      expect(fixture.actions.otpTickets.last, 'google-ticket');
      expect(fixture.actions.sentPhones.last, '+201012345678');
      await tester.enterText(find.byKey(const Key('auth-otp')), '123456');
      await _tap(tester, 'auth-verify-otp');
      expect(fixture.actions.verifyTicket, 'google-ticket');
      await tester.enterText(find.byKey(const Key('auth-name')), 'عميل جديد');
      await tester.enterText(
        find.byKey(const Key('auth-create-password')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('auth-confirm-password')),
        'new-password',
      );
      await _tap(tester, 'auth-register');
      expect(fixture.actions.registrationTicket, 'phone-verified-ticket');
      expect(fixture.actions.registrationEmail, isNull);
      expect(fixture.actions.registrationName, 'عميل جديد');
      expect(fixture.actions.commits, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'legacy new email uses server-authorized create-password method',
    (tester) async {
      final fixture = _Fixture()..actions.identityMethods = ['create_password'];
      await fixture.pump(tester);
      await _identify(tester, 'new@example.com');
      await tester.enterText(
        find.byKey(const Key('auth-name')),
        'New Customer',
      );
      await tester.enterText(
        find.byKey(const Key('auth-create-password')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('auth-confirm-password')),
        'different',
      );
      await _tap(tester, 'auth-register');
      expect(fixture.actions.passwordCalls, 0);
      await tester.enterText(
        find.byKey(const Key('auth-confirm-password')),
        'new-password',
      );
      await _tap(tester, 'auth-register');
      expect(fixture.actions.passwordCalls, 1);
      expect(fixture.actions.commits, 1);
    },
  );

  testWidgets(
    'native new email confirms password then verifies phone before creating account',
    (tester) async {
      final fixture = _Fixture()
        ..actions.identityMethods = ['create_password']
        ..actions.passwordResult = const NativeAuthResult(
          status: NativeAuthStatus.registrationRequired,
          ticket: 'email-enrollment',
          expiresIn: 300,
          fields: ['name', 'password', 'phone'],
        )
        ..actions.verifyResult = const NativeAuthResult(
          status: NativeAuthStatus.registrationRequired,
          ticket: 'verified-enrollment',
          expiresIn: 300,
          fields: ['name', 'password'],
        );
      await fixture.pump(tester);
      await _identify(tester, 'new@example.com');
      await tester.enterText(
        find.byKey(const Key('auth-name')),
        'New Customer',
      );
      expect(find.text('أنشئ كلمة مرور'), findsOneWidget);
      expect(find.byKey(const Key('auth-sign-in')), findsNothing);
      await tester.enterText(
        find.byKey(const Key('auth-create-password')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('auth-confirm-password')),
        'different',
      );
      await _tap(tester, 'auth-register');
      expect(fixture.actions.passwordCalls, 0);
      await tester.enterText(
        find.byKey(const Key('auth-confirm-password')),
        'new-password',
      );
      await _tap(tester, 'auth-register');
      expect(fixture.actions.commits, 0);
      expect(fixture.actions.registrationTicket, isNull);
      await tester.enterText(
        find.byKey(const Key('auth-phone')),
        '01012345678',
      );
      await _tap(tester, 'auth-send-otp');
      expect(fixture.actions.otpTickets.last, 'email-enrollment');
      await tester.enterText(find.byKey(const Key('auth-otp')), '123456');
      await _tap(tester, 'auth-verify-otp');
      // The collected name and password complete the verified ticket without a new form.
      expect(find.byKey(const Key('auth-name')), findsNothing);
      expect(fixture.actions.registrationTicket, 'verified-enrollment');
      expect(fixture.actions.registrationPassword, 'new-password');
      expect(fixture.actions.commits, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'email signup registration failure retries the new ticket without another OTP',
    (tester) async {
      final fixture = _Fixture();
      fixture.actions.identityMethods = ['create_password'];
      fixture.actions.passwordResult = const NativeAuthResult(
        status: NativeAuthStatus.registrationRequired,
        ticket: 'email-start',
        expiresIn: 300,
        fields: ['name', 'password', 'phone'],
      );
      fixture.actions.verifyResult = const NativeAuthResult(
        status: NativeAuthStatus.registrationRequired,
        ticket: 'email-complete',
        expiresIn: 300,
        fields: ['name', 'password'],
      );
      fixture.actions.registrationError = StateError('offline');
      await fixture.pump(tester);
      await _identify(tester, 'new@example.com');
      await tester.enterText(
        find.byKey(const Key('auth-name')),
        'New Customer',
      );
      await tester.enterText(
        find.byKey(const Key('auth-create-password')),
        'new-password',
      );
      await tester.enterText(
        find.byKey(const Key('auth-confirm-password')),
        'new-password',
      );
      await _tap(tester, 'auth-register');
      await tester.enterText(
        find.byKey(const Key('auth-phone')),
        '01012345678',
      );
      await _tap(tester, 'auth-send-otp');
      await tester.enterText(find.byKey(const Key('auth-otp')), '123456');
      await _tap(tester, 'auth-verify-otp');
      expect(fixture.actions.commits, 0);
      expect(find.byKey(const Key('auth-otp')), findsNothing);
      expect(find.byKey(const Key('auth-register')), findsOneWidget);
      fixture.actions.registrationError = null;
      await _tap(tester, 'auth-register');
      expect(fixture.actions.registrationTicket, 'email-complete');
      expect(fixture.actions.registrationName, 'New Customer');
      expect(fixture.actions.registrationPassword, 'new-password');
      expect(fixture.actions.commits, 1);
    },
  );

  testWidgets(
    'OTP-only phone identity sends code directly without asking for password',
    (tester) async {
      final fixture = _Fixture()..actions.identityMethods = ['phone_otp'];
      await fixture.pump(tester);
      await _identify(tester, '+201012345678');
      expect(fixture.actions.sentPhones, ['+201012345678']);
      expect(find.byKey(const Key('auth-otp')), findsOneWidget);
      expect(find.byKey(const Key('auth-password')), findsNothing);
      expect(fixture.actions.passwordCalls, 0);
      expect(fixture.actions.commits, 0);
    },
  );

  testWidgets('close stays enabled during Google and ignores its late result', (
    tester,
  ) async {
    final pending = Completer<NativeAuthResult>();
    final fixture = _Fixture()..actions.googleFuture = pending.future;
    await fixture.pump(tester);
    await _tap(tester, 'auth-google', settle: false);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('auth-close'))).onPressed,
      isNotNull,
    );
    await _tap(tester, 'auth-close');
    pending.complete(_authenticated());
    await tester.pumpAndSettle();
    expect(fixture.actions.cancelCalls, greaterThan(0));
    expect(fixture.actions.commits, 0);
    expect(find.text('CUSTOMER null'), findsOneWidget);
  });

  testWidgets(
    'change identifier cancels pending OTP and ignores late automatic result',
    (tester) async {
      final automatic = Completer<NativeAuthResult?>();
      final fixture = _Fixture()
        ..actions.automaticResults.add(automatic.future);
      await fixture.pump(tester);
      await _startOtp(tester);
      await _tap(tester, 'auth-change-email');
      automatic.complete(_authenticated());
      await tester.pumpAndSettle();
      expect(fixture.actions.cancelCalls, greaterThan(0));
      expect(fixture.actions.commits, 0);
      expect(find.byKey(const Key('auth-email')), findsOneWidget);
    },
  );

  testWidgets(
    'Google cancellation permits retry without leaving native screen',
    (tester) async {
      final fixture = _Fixture()
        ..actions.googleError = PlatformException(code: 'sign_in_canceled');
      await fixture.pump(tester);
      await _tap(tester, 'auth-google');
      expect(find.byKey(const Key('auth-error')), findsOneWidget);
      expect(fixture.actions.commits, 0);
      fixture.actions.googleError = null;
      await _tap(tester, 'auth-google');
      expect(fixture.actions.googleCalls, 2);
      expect(fixture.actions.commits, 1);
    },
  );

  testWidgets(
    'system back cancels pending proof and preserves original query',
    (tester) async {
      final pending = Completer<NativeAuthResult>();
      final fixture = _Fixture()..actions.googleFuture = pending.future;
      await fixture.pump(tester, route: '/account?tab=orders');
      fixture.router.push('/auth');
      await tester.pumpAndSettle();
      await _tap(tester, 'auth-google', settle: false);
      await _tap(tester, 'auth-google', settle: false);
      expect(fixture.actions.googleCalls, 1);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      pending.complete(_authenticated());
      await tester.pumpAndSettle();
      expect(fixture.actions.cancelCalls, greaterThan(0));
      expect(fixture.actions.commits, 0);
      expect(
        fixture.router.routeInformationProvider.value.uri.toString(),
        '/account?tab=orders',
      );
    },
  );

  testWidgets('configuration failure can retry in the native screen', (
    tester,
  ) async {
    final fixture = _Fixture()..actions.configError = StateError('unavailable');
    await fixture.pump(tester);
    expect(find.byKey(const Key('auth-config-retry')), findsOneWidget);
    fixture.actions.configError = null;
    await _tap(tester, 'auth-config-retry');
    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    expect(fixture.actions.configCalls, 2);
  });

  testWidgets('pushed auth closes and succeeds back to original query', (
    tester,
  ) async {
    final fixture = _Fixture();
    await fixture.pump(tester, route: '/account?tab=saved');
    fixture.router.push('/auth');
    await tester.pumpAndSettle();
    await _tap(tester, 'auth-close');
    expect(
      fixture.router.routeInformationProvider.value.uri.toString(),
      '/account?tab=saved',
    );
    fixture.router.push('/auth');
    await tester.pumpAndSettle();
    await _identify(tester, 'customer@example.com');
    await tester.enterText(
      find.byKey(const Key('auth-password')),
      'valid-password',
    );
    await _tap(tester, 'auth-sign-in');
    expect(
      fixture.router.routeInformationProvider.value.uri.toString(),
      '/account?tab=saved',
    );
  });
}

Future<void> _tap(WidgetTester tester, String key, {bool settle = true}) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  // A native frame must lay out the scrolled control before hit testing it.
  await tester.pump();
  await tester.tap(find.byKey(Key(key)));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Future<void> _identify(WidgetTester tester, String identifier) async {
  await tester.enterText(find.byKey(const Key('auth-email')), identifier);
  await _tap(tester, 'auth-continue');
}

Future<void> _startOtp(WidgetTester tester) async {
  await _identify(tester, '01012345678');
  await _tap(tester, 'auth-use-otp');
}

class _TestAuthController extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
  void publish(AuthSession session) => state = AsyncData(session);
}

class _Fixture {
  _Fixture({_Actions? actions}) : actions = actions ?? _Actions();
  final _Actions actions;
  final auth = _TestAuthController();
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    String route = '/auth',
    String logo = '',
    LastLoginMethod? lastLogin,
    double logoScale = 1,
    NativeAuthActions? previewActions,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    actions.onCommit = auth.publish;
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
        GoRoute(path: '/account', builder: (_, _) => account()),
        GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
        GoRoute(path: '/checkout', builder: (_, _) => protected()),
        GoRoute(path: '/orders', builder: (_, _) => protected()),
        GoRoute(path: '/profile', builder: (_, _) => protected()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => auth),
          lastLoginMethodProvider.overrideWith((_) async => lastLogin),
          nativeAuthActionsProvider.overrideWithValue(
            previewActions ?? actions,
          ),
          if (previewActions == null)
            nativeAuthConfigProvider.overrideWith((ref) => actions.config()),
          applicationIdentity58Provider.overrideWithValue({
            'app_name': 'متجر الاختبار',
          }),
          cmsPageLayoutProvider('account').overrideWith(
            (_) async => CmsPageLayout.fromJson({
              'page': 'account',
              'header': {
                'settings': {'logo_url': logo, 'auth_logo_scale': logoScale},
              },
            }),
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

class _EnrollmentActions extends _Actions
    implements NativePhoneEnrollmentActions {
  _EnrollmentActions({bool supported = true}) {
    configuration = NativeAuthConfig(
      phoneCountryCode: configuration.phoneCountryCode,
      methods: configuration.methods,
      supportsUnverifiedPhoneEnrollment: supported,
      supportsExpectedPhoneGoogle: configuration.supportsExpectedPhoneGoogle,
    );
  }
  int prepareCalls = 0;
  int confirmCalls = 0;
  Object? prepareError;
  @override
  Future<NativeAuthResult> preparePhone(String phone, {String? ticket}) async {
    prepareCalls++;
    if (prepareError != null) throw prepareError!;
    return NativeAuthResult(
      status: NativeAuthStatus.registrationRequired,
      ticket: 'prepared-$prepareCalls',
      expiresIn: 300,
      fields: const ['name', 'password', 'phone'],
    );
  }

  @override
  Future<NativeAuthResult> confirmUnverifiedPhone(
    String ticket,
    String phone,
  ) async {
    confirmCalls++;
    return const NativeAuthResult(
      status: NativeAuthStatus.registrationRequired,
      ticket: 'contact-only-profile',
      expiresIn: 300,
      fields: ['name', 'password'],
    );
  }
}

class _Actions
    implements
        NativeAuthActions,
        NativeExistingPhoneGoogleActions,
        NativeAppleAuthActions {
  @override
  Future<NativeAuthResult> apple() async => const NativeAuthResult(
    status: NativeAuthStatus.registrationRequired,
    ticket: 'apple-fixture',
    fields: ['name'],
    expiresIn: 300,
  );
  NativeAuthConfig configuration = const NativeAuthConfig(
    phoneCountryCode: '20',
    supportsExpectedPhoneGoogle: true,
    methods: {
      'email_password': true,
      'phone_password': true,
      'phone_otp': true,
      'google': true,
    },
  );
  List<String>? identityMethods;
  Object? registrationError;
  NativeAuthResult? verifyResult;
  NativeAuthResult? passwordResult;
  NativeAuthResult? googleResult;
  Future<NativeAuthResult>? verifyFuture;
  Future<NativeAuthResult>? googleFuture;
  Object? googleError;
  String? expectedGooglePhone;
  Object? verifyError;
  Object? sendError;
  Object? commitError;
  Object? configError;
  final identifiers = <String>[];
  final sentPhones = <String>[];
  final otpTickets = <String?>[];
  final resends = <NativeOtpChallenge?>[];
  final automaticResults = <Future<NativeAuthResult?>>[];
  int configCalls = 0;
  int passwordCalls = 0;
  int googleCalls = 0;
  int commits = 0;
  int cancelCalls = 0;
  int? selectedAccount;
  String? selectionTicket;
  String? verifyTicket;
  String? registrationTicket;
  String? registrationEmail;
  String? registrationName;
  String? registrationPassword;
  void Function(AuthSession)? onCommit;

  @override
  Future<NativeAuthConfig> config() async {
    configCalls++;
    if (configError != null) throw configError!;
    return configuration;
  }

  @override
  Future<NativeAuthIdentity> identify(String identifier) async {
    identifiers.add(identifier);
    return NativeAuthIdentity(
      identifier: identifier,
      kind: identifier.contains('@') ? 'email' : 'phone',
      methods:
          identityMethods ??
          (identifier.contains('@') ? ['password'] : ['password', 'phone_otp']),
    );
  }

  @override
  Future<NativeAuthResult> password(String identifier, String password) async {
    passwordCalls++;
    return passwordResult ?? _authenticated();
  }

  @override
  Future<NativeOtpChallenge> sendOtp(
    String phone, {
    NativeOtpChallenge? resend,
    String? ticket,
  }) async {
    sentPhones.add(phone);
    resends.add(resend);
    otpTickets.add(ticket);
    if (sendError != null) throw sendError!;
    return NativeOtpChallenge(
      phone: phone,
      handle: Object(),
      resendToken: sentPhones.length,
      automaticResult: automaticResults.isEmpty
          ? Future.value(null)
          : automaticResults.removeAt(0),
    );
  }

  @override
  Future<NativeAuthResult> verifyOtp(
    NativeOtpChallenge challenge,
    String code, {
    String? ticket,
  }) async {
    verifyTicket = ticket;
    if (verifyError != null) throw verifyError!;
    return verifyFuture == null
        ? verifyResult ?? _authenticated()
        : await verifyFuture!;
  }

  @override
  Future<NativeAuthResult> google() async {
    googleCalls++;
    if (googleError != null) throw googleError!;
    return googleFuture == null
        ? googleResult ?? _authenticated()
        : await googleFuture!;
  }

  @override
  Future<NativeAuthResult> googleForPhone(String expectedPhone) {
    expectedGooglePhone = expectedPhone;
    return google();
  }

  @override
  Future<NativeAuthResult> selectAccount(String ticket, int accountId) async {
    selectionTicket = ticket;
    selectedAccount = accountId;
    return _authenticated();
  }

  @override
  Future<NativeAuthResult> register(
    String ticket, {
    required String name,
    required String password,
    String? email,
  }) async {
    registrationTicket = ticket;
    registrationName = name;
    registrationPassword = password;
    registrationEmail = email;
    if (registrationError != null) throw registrationError!;
    return _authenticated();
  }

  @override
  Future<AuthSession> commit(NativeAuthResult result) async {
    commits++;
    if (commitError != null) throw commitError!;
    onCommit?.call(result.session!);
    return result.session!;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
  }
}

NativeAuthResult _authenticated() => NativeAuthResult(
  status: NativeAuthStatus.authenticated,
  session: AuthSession(
    token: 'native-test-session',
    expiresAt: DateTime.now().toUtc().add(const Duration(days: 1)),
    user: const AuthUser(id: 7, email: 'customer@example.com'),
  ),
);
