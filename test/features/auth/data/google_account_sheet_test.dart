import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_sdk.dart';

const _proof = AuthenticationResults(
  user: GoogleSignInUserData(email: 'test@example.com', id: 'test'),
  authenticationTokens: AuthenticationTokenData(idToken: 'test-proof'),
);

class _GooglePlatform extends GoogleSignInPlatform {
  final calls = <String>[];
  AuthenticationResults? sheetResult = _proof;
  GoogleSignInExceptionCode? sheetError;

  @override
  Future<void> init(InitParameters params) async {}
  @override
  bool supportsAuthenticate() => true;
  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async {
    calls.add('sheet');
    if (sheetError case final code?) {
      throw GoogleSignInException(code: code);
    }
    return sheetResult;
  }

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    calls.add('explicit');
    return _proof;
  }

  @override
  Future<void> signOut(SignOutParams params) async => calls.add('clear');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'Android sheet selection, fallback, cancellation and native iOS flow',
    () async {
      final old = GoogleSignInPlatform.instance;
      final platform = _GooglePlatform();
      GoogleSignInPlatform.instance = platform;
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() {
        GoogleSignInPlatform.instance = old;
        debugDefaultTargetPlatformOverride = null;
      });
      final sdk = FirebaseNativeAuthSdk(isWeb: false);
      const config = {
        'google': {'server_client_id': 'merchant.apps.googleusercontent.com'},
      };

      expect(await sdk.google(config), 'test-proof');
      expect(platform.calls, ['sheet', 'clear']);

      platform.calls.clear();
      platform.sheetResult = null;
      expect(await sdk.google(config), 'test-proof');
      expect(
        platform.calls,
        ['sheet', 'explicit', 'clear'],
        reason: 'No eligible account must allow adding another account',
      );

      platform.calls.clear();
      platform.sheetError = GoogleSignInExceptionCode.uiUnavailable;
      expect(await sdk.google(config), 'test-proof');
      expect(platform.calls, ['sheet', 'explicit', 'clear']);

      for (final code in [
        GoogleSignInExceptionCode.canceled,
        GoogleSignInExceptionCode.interrupted,
        GoogleSignInExceptionCode.providerConfigurationError,
      ]) {
        platform.calls.clear();
        platform.sheetError = code;
        await expectLater(
          sdk.google(config),
          throwsA(isA<NativeAuthSdkException>()),
        );
        expect(platform.calls, [
          'sheet',
          'clear',
        ], reason: '$code must not open a second picker');
      }

      platform.calls.clear();
      platform.sheetError = null;
      platform.sheetResult = const AuthenticationResults(
        user: GoogleSignInUserData(email: 'test@example.com', id: 'test'),
        authenticationTokens: AuthenticationTokenData(idToken: null),
      );
      await expectLater(
        sdk.google(config),
        throwsA(
          isA<NativeAuthSdkException>().having(
            (error) => error.code,
            'code',
            'missing-id-token',
          ),
        ),
      );
      expect(platform.calls, ['sheet', 'clear']);

      // The backend is shared, but the Android-only UI must never run on iOS.
      platform.calls.clear();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(await sdk.google(config), 'test-proof');
      expect(platform.calls, ['explicit', 'clear']);
    },
  );
}
