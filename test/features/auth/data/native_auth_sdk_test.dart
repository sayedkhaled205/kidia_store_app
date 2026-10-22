import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_sdk.dart';

const config = <String, dynamic>{
  'firebase': {
    'apiKey': 'public-merchant-key',
    'projectId': 'merchant-auth',
    'appId': '1:123:android:merchantapp',
    'messagingSenderId': '123',
  },
  'google': {'server_client_id': 'merchant.apps.googleusercontent.com'},
};

Matcher sdkError(String code) => isA<NativeAuthSdkException>().having(
  (error) => error.code,
  'safe error code',
  code,
);

Future<void> settle() => Future<void>.delayed(Duration.zero);

class PhoneBackend implements NativePhoneBackend {
  late void Function(PhoneAuthCredential) completed;
  late void Function(Object, StackTrace) failed;
  late void Function(String, int?) sent;
  late void Function(String) timedOut;
  String? phone;
  int? resendToken;
  int tokenCalls = 0;
  int signOutCalls = 0;
  Future<void> launch = Future<void>.value();
  Future<String> Function() issueToken = () async => 'firebase-proof';

  @override
  Future<void> verify({
    required String phone,
    int? resendToken,
    required void Function(PhoneAuthCredential) completed,
    required void Function(Object, StackTrace) failed,
    required void Function(String, int?) sent,
    required void Function(String) timedOut,
  }) {
    this.phone = phone;
    this.resendToken = resendToken;
    this.completed = completed;
    this.failed = failed;
    this.sent = sent;
    this.timedOut = timedOut;
    return launch;
  }

  @override
  Future<String> tokenFor(PhoneAuthCredential credential) {
    tokenCalls++;
    return issueToken();
  }

  @override
  Future<void> signOut() async => signOutCalls++;
}

class GoogleBackend implements NativeGoogleBackend {
  String? serverClientId;
  String? clientId;
  int calls = 0;
  Future<String> Function() issueToken = () async => 'google-id-proof';

  @override
  Future<String> authenticate({
    required String serverClientId,
    String? clientId,
  }) {
    calls++;
    this.serverClientId = serverClientId;
    this.clientId = clientId;
    return issueToken();
  }
}

void main() {
  late PhoneBackend phone;
  late GoogleBackend google;
  late FirebaseNativeAuthSdk sdk;
  Map<String, dynamic>? initializedOptions;
  setUp(() {
    phone = PhoneBackend();
    google = GoogleBackend();
    initializedOptions = null;
    sdk = FirebaseNativeAuthSdk(
      platform: TargetPlatform.android,
      isWeb: false,
      phoneBackendFactory: (options) async {
        initializedOptions = options;
        return phone;
      },
      googleBackend: google,
    );
  });
  tearDown(() => sdk.cancel());

  Future<NativePhoneChallenge> sentChallenge({int? resendToken}) async {
    final started = sdk.startPhone(
      config: config,
      phone: '+201012345678',
      resendToken: resendToken,
    );
    await settle();
    phone.sent('verification-1', 42);
    return started;
  }

  PhoneAuthCredential credential() => PhoneAuthProvider.credential(
    verificationId: 'verification-1',
    smsCode: '123456',
  );

  test(
    'uses merchant options and never substitutes push/default options',
    () async {
      final challenge = await sentChallenge();
      expect(initializedOptions!['projectId'], 'merchant-auth');
      expect(initializedOptions!['appId'], '1:123:android:merchantapp');
      expect(challenge.resendToken, 42);
      expect(phone.phone, '+201012345678');
    },
  );

  test(
    'rejects website-only Firebase app before starting native verification',
    () async {
      await expectLater(
        sdk.startPhone(
          config: {
            ...config,
            'firebase': {
              ...config['firebase'] as Map,
              'appId': '1:123:web:site',
            },
          },
          phone: '+201012345678',
        ),
        throwsA(sdkError('phone-native-registration-required')),
      );
      expect(initializedOptions, isNull);
    },
  );

  test('does not assume a country for local phone numbers', () async {
    await expectLater(
      sdk.startPhone(config: config, phone: '01012345678'),
      throwsA(sdkError('invalid-phone-number')),
    );
    expect(initializedOptions, isNull);
  });

  test(
    'manual OTP produces exactly one proof and disables auto completion',
    () async {
      final challenge = await sentChallenge();
      expect(await sdk.verifyPhone(challenge, '123456'), 'firebase-proof');
      phone.completed(credential());
      expect(await challenge.automaticIdToken, isNull);
      expect(phone.tokenCalls, 1);
    },
  );

  test(
    'instant verification returns an automatic proof without SMS screen',
    () async {
      final started = sdk.startPhone(config: config, phone: '+201012345678');
      await settle();
      phone.completed(credential());
      final challenge = await started;
      expect(challenge.verificationId, isEmpty);
      expect(await challenge.automaticIdToken, 'firebase-proof');
      phone.sent('late-id', 10);
      phone.completed(credential());
      expect(phone.tokenCalls, 1);
    },
  );

  test(
    'manual and auto race cannot create duplicate native proof exchanges',
    () async {
      final issued = Completer<String>();
      phone.issueToken = () => issued.future;
      final challenge = await sentChallenge();
      phone.completed(credential());
      await expectLater(
        sdk.verifyPhone(challenge, '123456'),
        throwsA(sdkError('verification-in-progress')),
      );
      issued.complete('one-proof');
      expect(await challenge.automaticIdToken, 'one-proof');
      expect(phone.tokenCalls, 1);
    },
  );

  test('auto callback during manual verification is ignored', () async {
    final issued = Completer<String>();
    phone.issueToken = () => issued.future;
    final challenge = await sentChallenge();
    final manual = sdk.verifyPhone(challenge, '123456');
    phone.completed(credential());
    issued.complete('manual-proof');
    expect(await manual, 'manual-proof');
    expect(await challenge.automaticIdToken, isNull);
    expect(phone.tokenCalls, 1);
  });

  test('incorrect OTP can be retried on the same challenge', () async {
    final challenge = await sentChallenge();
    phone.issueToken = () async =>
        throw FirebaseAuthException(code: 'invalid-verification-code');
    await expectLater(
      sdk.verifyPhone(challenge, '000000'),
      throwsA(sdkError('invalid-verification-code')),
    );
    phone.issueToken = () async => 'retry-proof';
    expect(await sdk.verifyPhone(challenge, '123456'), 'retry-proof');
  });

  test(
    'auto retrieval timeout still permits manual OTP verification',
    () async {
      final challenge = await sentChallenge();
      phone.timedOut('verification-1');
      expect(await challenge.automaticIdToken, isNull);
      expect(await sdk.verifyPhone(challenge, '123456'), 'firebase-proof');
    },
  );

  test(
    'cancel invalidates already delivered challenge and clears secondary auth',
    () async {
      final challenge = await sentChallenge();
      await sdk.cancel();
      phone.completed(credential());
      await expectLater(
        sdk.verifyPhone(challenge, '123456'),
        throwsA(sdkError('cancelled')),
      );
      expect(await challenge.automaticIdToken, isNull);
      expect(phone.tokenCalls, 0);
      expect(phone.signOutCalls, 1);
    },
  );

  test(
    'cancel ignores an automatic token arriving after the page closed',
    () async {
      final issued = Completer<String>();
      phone.issueToken = () => issued.future;
      final challenge = await sentChallenge();
      phone.completed(credential());
      await sdk.cancel();
      issued.complete('discarded-token');
      await settle();
      expect(await challenge.automaticIdToken, isNull);
    },
  );

  test(
    'cancel completes pending start without waiting for SDK launch future',
    () async {
      final launch = Completer<void>();
      phone.launch = launch.future;
      final started = sdk.startPhone(config: config, phone: '+201012345678');
      final failure = expectLater(started, throwsA(sdkError('cancelled')));
      await settle();
      await sdk.cancel();
      await failure;
      launch.complete();
    },
  );

  test(
    'resend invalidates previous callbacks and preserves provider resend token',
    () async {
      final old = await sentChallenge();
      final oldCompleted = phone.completed;
      final newer = await sentChallenge(resendToken: old.resendToken);
      oldCompleted(credential());
      expect(await old.automaticIdToken, isNull);
      expect(phone.resendToken, 42);
      expect(phone.tokenCalls, 0);
      expect(await sdk.verifyPhone(newer, '123456'), 'firebase-proof');
    },
  );

  test(
    'Google returns raw Google ID token to merchant and uses server client ID',
    () async {
      expect(await sdk.google(config), 'google-id-proof');
      expect(google.serverClientId, 'merchant.apps.googleusercontent.com');
      expect(google.clientId, isNull);
    },
  );

  test('Google cancellation discards late account picker result', () async {
    final issued = Completer<String>();
    google.issueToken = () => issued.future;
    final result = sdk.google(config);
    final failure = expectLater(result, throwsA(sdkError('cancelled')));
    await sdk.cancel();
    issued.complete('discarded-google-token');
    await failure;
  });

  test(
    'Google does not initialize with missing or invalid merchant client ID',
    () async {
      await expectLater(
        sdk.google({
          'google': {'server_client_id': 'https://other.example'},
        }),
        throwsA(sdkError('google-native-registration-required')),
      );
      expect(google.calls, 0);
    },
  );

  test('provider errors do not expose provider account data', () async {
    google.issueToken = () async =>
        throw StateError('private@example.com secret');
    await expectLater(
      sdk.google(config),
      throwsA(sdkError('identity-provider-unavailable')),
    );
  });

  test(
    'iOS requires native registration and passes its own OAuth client ID',
    () async {
      sdk = FirebaseNativeAuthSdk(
        platform: TargetPlatform.iOS,
        isWeb: false,
        phoneBackendFactory: (options) async {
          initializedOptions = options;
          return phone;
        },
        googleBackend: google,
      );
      final iosConfig = {
        ...config,
        'firebase': {
          ...config['firebase'] as Map,
          'ios': {
            'appId': '1:123:ios:merchantapp',
            'iosBundleId': 'app.merchant',
          },
        },
        'google': {
          ...config['google'] as Map,
          'ios_client_id': 'ios.apps.googleusercontent.com',
        },
      };
      final started = sdk.startPhone(config: iosConfig, phone: '+201012345678');
      await settle();
      phone.sent('ios-verification', null);
      await started;
      expect(initializedOptions!['appId'], '1:123:ios:merchantapp');
      expect(await sdk.google(iosConfig), 'google-id-proof');
      expect(google.clientId, 'ios.apps.googleusercontent.com');
    },
  );

  test(
    'unsupported platforms never fall back to a website or browser',
    () async {
      sdk = FirebaseNativeAuthSdk(
        platform: TargetPlatform.windows,
        isWeb: false,
        phoneBackendFactory: (_) async => phone,
        googleBackend: google,
      );
      await expectLater(
        sdk.google(config),
        throwsA(sdkError('native-platform-required')),
      );
      await expectLater(
        sdk.startPhone(config: config, phone: '+201012345678'),
        throwsA(sdkError('native-platform-required')),
      );
      expect(google.calls, 0);
    },
  );
}
