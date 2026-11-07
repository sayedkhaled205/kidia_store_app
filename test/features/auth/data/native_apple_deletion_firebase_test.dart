import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
// Test the installed Firebase adapter through its platform test boundary.
// ignore: depend_on_referenced_packages
import 'package:firebase_auth_platform_interface/firebase_auth_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_sdk.dart';

class MerchantCore extends MockFirebaseApp {
  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async => CoreInitializeResponse(
    name: appName,
    options: initializeAppRequest,
    pluginConstants: {},
  );
}

class AuthPlatform extends FirebaseAuthPlatform {
  @override
  late FirebaseApp app;
  final calls = <String>[];
  String? code = 'memory-only-apple-code';
  String? token = 'fresh-merchant-jwt';
  bool failRevoke = false;
  bool failDelete = false;
  bool switchAfterRevoke = false;
  @override
  UserPlatform? currentUser;

  @override
  FirebaseAuthPlatform delegateFor({required FirebaseApp app}) {
    this.app = app;
    return this;
  }

  @override
  FirebaseAuthPlatform setInitialValues({
    InternalUserDetails? currentUser,
    String? languageCode,
  }) => this;

  @override
  Future<UserCredentialPlatform> signInWithProvider(
    AuthProvider provider,
  ) async {
    expect(provider.providerId, 'apple.com');
    calls.add('appleSignIn');
    currentUser = TestUser(this, 'apple-customer');
    return TestCredential(
      auth: this,
      user: currentUser,
      additionalUserInfo: AdditionalUserInfo(
        isNewUser: false,
        providerId: 'apple.com',
        authorizationCode: code,
      ),
    );
  }

  @override
  Future<void> revokeTokenWithAuthorizationCode(
    String authorizationCode,
  ) async {
    expect(authorizationCode, code);
    calls.add('revoke');
    if (failRevoke) throw StateError('private-provider-detail');
    if (switchAfterRevoke) currentUser = TestUser(this, 'other-customer');
  }

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    currentUser = null;
  }
}

class TestCredential extends UserCredentialPlatform {
  TestCredential({required super.auth, super.user, super.additionalUserInfo});
}

class TestMultiFactor extends MultiFactorPlatform {
  TestMultiFactor(super.auth);
}

class TestUser extends UserPlatform {
  TestUser(AuthPlatform auth, String uid)
    : super(
        auth,
        TestMultiFactor(auth),
        InternalUserDetails(
          userInfo: InternalUserInfo(
            uid: uid,
            isAnonymous: false,
            isEmailVerified: true,
          ),
          providerData: [],
        ),
      );

  @override
  Future<String?> getIdToken(bool forceRefresh) async {
    expect(forceRefresh, true);
    (auth as AuthPlatform).calls.add('freshToken');
    return (auth as AuthPlatform).token;
  }

  @override
  Future<void> delete() async {
    final platform = auth as AuthPlatform;
    expect(uid, 'apple-customer');
    platform.calls.add('delete');
    if (platform.failDelete) throw StateError('private-delete-detail');
    platform.currentUser = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  TestFirebaseCoreHostApi.setUp(MerchantCore());
  var sequence = 0;
  late AuthPlatform platform;
  late Map<String, dynamic> config;
  late FirebaseNativeAuthSdk sdk;
  setUp(() {
    platform = AuthPlatform();
    FirebaseAuthPlatform.instance = platform;
    config = {
      'firebase': {
        'projectId': 'merchant-auth-${sequence++}',
        'appId': '1:123:ios:merchant-$sequence',
        'apiKey': 'public-test-config',
        'messagingSenderId': '123',
        'iosBundleId': 'app.merchant',
      },
    };
    sdk = FirebaseNativeAuthSdk(platform: TargetPlatform.iOS, isWeb: false);
  });

  test(
    'real adapter uses named merchant app, fresh proof, revoke, captured user delete and cleanup',
    () async {
      await sdk.deleteAppleIdentity(
        config,
        validateIdentity: (token) async {
          expect(token, 'fresh-merchant-jwt');
          platform.calls.add('validate');
          return true;
        },
        isCurrentAccount: () => true,
      );
      expect(platform.app.name, startsWith('mobishop-merchant-auth-'));
      expect(platform.app.options.projectId, config['firebase']['projectId']);
      expect(platform.calls, [
        'signOut',
        'appleSignIn',
        'freshToken',
        'validate',
        'revoke',
        'delete',
        'signOut',
      ]);
      expect(platform.currentUser, null);
    },
  );

  for (final missing in ['code', 'token']) {
    test(
      'missing $missing closes provider session before merchant validation',
      () async {
        if (missing == 'code') {
          platform.code = null;
        } else {
          platform.token = null;
        }
        var validations = 0;
        await expectLater(
          sdk.deleteAppleIdentity(
            config,
            validateIdentity: (_) async {
              validations++;
              return true;
            },
            isCurrentAccount: () => true,
          ),
          throwsA(isA<NativeAuthSdkException>()),
        );
        expect(validations, 0);
        expect(platform.calls, [
          'signOut',
          'appleSignIn',
          'freshToken',
          'signOut',
        ]);
        expect(platform.currentUser, null);
      },
    );
  }

  test(
    'cancelling a queued deletion does not reopen Apple after the lock is released',
    () async {
      final entered = Completer<void>();
      final release = Completer<bool>();
      final first = sdk.deleteAppleIdentity(
        config,
        validateIdentity: (_) {
          entered.complete();
          return release.future;
        },
        isCurrentAccount: () => true,
      );
      await entered.future;
      final secondSdk = FirebaseNativeAuthSdk(
        platform: TargetPlatform.iOS,
        isWeb: false,
      );
      final second = secondSdk.deleteAppleIdentity(
        config,
        validateIdentity: (_) async => true,
        isCurrentAccount: () => true,
      );
      final assertion = expectLater(
        second,
        throwsA(
          isA<NativeAuthSdkException>().having(
            (e) => e.code,
            'safe code',
            'cancelled',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await secondSdk.cancel();
      release.complete(true);
      await first;
      await assertion;
      expect(
        platform.calls.where((call) => call == 'appleSignIn'),
        hasLength(1),
      );
      expect(platform.calls.where((call) => call == 'delete'), hasLength(1));
      expect(platform.currentUser, null);
    },
  );

  for (final stage in ['validate', 'revoke', 'delete']) {
    test('real adapter signs out after failure during $stage', () async {
      platform.failRevoke = stage == 'revoke';
      platform.failDelete = stage == 'delete';
      await expectLater(
        sdk.deleteAppleIdentity(
          config,
          validateIdentity: (_) async => stage != 'validate',
          isCurrentAccount: () => true,
        ),
        throwsA(isA<NativeAuthSdkException>()),
      );
      expect(platform.calls.last, 'signOut');
      expect(platform.currentUser, null);
      if (stage != 'delete') expect(platform.calls, isNot(contains('delete')));
      if (stage == 'validate') {
        expect(platform.calls, isNot(contains('revoke')));
      }
    });
  }

  for (final duringRevoke in [false, true]) {
    test(
      'provider UID change ${duringRevoke ? 'after revoke' : 'before revoke'} blocks next mutation',
      () async {
        platform.switchAfterRevoke = duringRevoke;
        await expectLater(
          sdk.deleteAppleIdentity(
            config,
            validateIdentity: (_) async {
              if (!duringRevoke) {
                platform.currentUser = TestUser(platform, 'another-customer');
              }
              return true;
            },
            isCurrentAccount: () => true,
          ),
          throwsA(
            isA<NativeAuthSdkException>().having(
              (e) => e.code,
              'safe code',
              'identity-changed',
            ),
          ),
        );
        expect(platform.calls, isNot(contains('delete')));
        if (!duringRevoke) expect(platform.calls, isNot(contains('revoke')));
        expect(platform.currentUser, null);
      },
    );
  }
}
