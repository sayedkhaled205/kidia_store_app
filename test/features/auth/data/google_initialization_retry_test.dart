import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_sdk.dart';

class _GooglePlatform extends GoogleSignInPlatform {
  int initializations = 0;
  int authentications = 0;
  int signOuts = 0;
  @override
  Future<void> init(InitParameters params) async {
    initializations++;
    if (initializations == 1) throw StateError('temporarily unavailable');
  }

  @override
  bool supportsAuthenticate() => true;
  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async => null;
  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    authentications++;
    return const AuthenticationResults(
      user: GoogleSignInUserData(email: 'test@example.com', id: 'test'),
      authenticationTokens: AuthenticationTokenData(idToken: 'test-proof'),
    );
  }

  @override
  Future<void> signOut(SignOutParams params) async {
    signOuts++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'real Google backend retries initialization after a transient platform failure',
    () async {
      final old = GoogleSignInPlatform.instance;
      final platform = _GooglePlatform();
      GoogleSignInPlatform.instance = platform;
      addTearDown(() => GoogleSignInPlatform.instance = old);
      final sdk = FirebaseNativeAuthSdk(
        platform: TargetPlatform.android,
        isWeb: false,
      );
      const config = {
        'google': {'server_client_id': 'merchant.apps.googleusercontent.com'},
      };
      await expectLater(
        sdk.google(config),
        throwsA(isA<NativeAuthSdkException>()),
      );
      expect(platform.authentications, 0);
      expect(await sdk.google(config), 'test-proof');
      expect(platform.initializations, 2);
      expect(platform.authentications, 1);
      expect(platform.signOuts, 1);
      expect(await sdk.google(config), 'test-proof');
      expect(platform.initializations, 2);
    },
  );
}
