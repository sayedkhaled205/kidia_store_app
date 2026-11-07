import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_sdk.dart';

const config = <String, dynamic>{
  'firebase': {
    'projectId': 'merchant-auth',
    'appId': '1:123:ios:merchant',
    'apiKey': 'public-fixture',
    'messagingSenderId': '123',
    'iosBundleId': 'app.merchant',
  },
};

Matcher sdkError(String code) => isA<NativeAuthSdkException>().having(
  (error) => error.code,
  'safe code',
  code,
);

class DeletionBackend
    implements NativeAppleBackend, NativeAppleDeletionBackend {
  final calls = <String>[];
  String token = 'fresh-firebase-proof';
  Future<void> Function()? onAuthenticate;
  Future<void> Function()? onRevoke;
  Future<void> Function()? onDelete;
  Future<void> Function()? onSignOut;

  @override
  Future<NativeAppleProof> authenticate() async {
    calls.add('normal-login');
    return NativeAppleProof(token, name: 'Customer');
  }

  @override
  Future<void> withDeletionSession(
    Future<void> Function(NativeAppleDeletionSession session) action, {
    required void Function() checkCurrent,
  }) async {
    checkCurrent();
    try {
      calls.add('authenticate');
      await onAuthenticate?.call();
      await action(
        NativeAppleDeletionSession(
          idToken: token,
          revokeAuthorization: () async {
            calls.add('revoke');
            await onRevoke?.call();
          },
          deleteIdentity: () async {
            calls.add('delete');
            await onDelete?.call();
          },
        ),
      );
    } finally {
      calls.add('signOut');
      await onSignOut?.call();
    }
  }
}

FirebaseNativeAuthSdk sdkFor(DeletionBackend backend) => FirebaseNativeAuthSdk(
  appleBackendFactory: (_) async => backend,
  platform: TargetPlatform.iOS,
  isWeb: false,
);

void main() {
  test(
    'server approval precedes revocation and deletion in merchant context',
    () async {
      final backend = DeletionBackend();
      Map<String, dynamic>? options;
      final sdk = FirebaseNativeAuthSdk(
        appleBackendFactory: (value) async {
          options = value;
          return backend;
        },
        platform: TargetPlatform.iOS,
        isWeb: false,
      );
      await sdk.deleteAppleIdentity(
        config,
        validateIdentity: (token) async {
          expect(token, backend.token);
          backend.calls.add('validate');
          return true;
        },
        isCurrentAccount: () => true,
      );
      expect(options, config['firebase']);
      expect(backend.calls, [
        'authenticate',
        'validate',
        'revoke',
        'delete',
        'signOut',
      ]);
    },
  );

  test('wrong Apple account cannot revoke or delete its identity', () async {
    final backend = DeletionBackend();
    await expectLater(
      sdkFor(backend).deleteAppleIdentity(
        config,
        validateIdentity: (_) async => false,
        isCurrentAccount: () => true,
      ),
      throwsA(sdkError('identity-mismatch')),
    );
    expect(backend.calls, ['authenticate', 'signOut']);
  });

  test('missing proof never reaches the merchant validator', () async {
    final backend = DeletionBackend()..token = '';
    var validations = 0;
    await expectLater(
      sdkFor(backend).deleteAppleIdentity(
        config,
        validateIdentity: (_) async {
          validations++;
          return true;
        },
        isCurrentAccount: () => true,
      ),
      throwsA(sdkError('missing-id-token')),
    );
    expect(validations, 0);
    expect(backend.calls, ['authenticate', 'signOut']);
  });

  test('already changed merchant account never opens Apple', () async {
    final backend = DeletionBackend();
    await expectLater(
      sdkFor(backend).deleteAppleIdentity(
        config,
        validateIdentity: (_) async => true,
        isCurrentAccount: () => false,
      ),
      throwsA(sdkError('account-changed')),
    );
    expect(backend.calls, isEmpty);
  });

  for (final cancelled in [false, true]) {
    for (final stage in ['authenticate', 'validate', 'revoke']) {
      test(
        '${cancelled ? 'cancellation' : 'account switch'} during $stage stops the next mutation',
        () async {
          final backend = DeletionBackend();
          final sdk = sdkFor(backend);
          final entered = Completer<void>();
          final release = Completer<void>();
          var current = true;
          Future<void> hold() async {
            entered.complete();
            await release.future;
          }

          if (stage == 'authenticate') backend.onAuthenticate = hold;
          if (stage == 'revoke') backend.onRevoke = hold;
          final operation = sdk.deleteAppleIdentity(
            config,
            validateIdentity: (_) async {
              backend.calls.add('validate');
              if (stage == 'validate') await hold();
              return true;
            },
            isCurrentAccount: () => current,
          );
          final assertion = expectLater(
            operation,
            throwsA(sdkError(cancelled ? 'cancelled' : 'account-changed')),
          );
          await entered.future;
          if (cancelled) {
            await sdk.cancel();
          } else {
            current = false;
          }
          release.complete();
          await assertion;
          expect(backend.calls.last, 'signOut');
          expect(backend.calls, isNot(contains('delete')));
          if (stage != 'revoke') {
            expect(backend.calls, isNot(contains('revoke')));
          }
          if (stage == 'authenticate') {
            expect(backend.calls, isNot(contains('validate')));
          }
        },
      );
    }
  }

  test(
    'cancelled factory cannot later open an Apple deletion session',
    () async {
      final pending = Completer<NativeAppleBackend>();
      final backend = DeletionBackend();
      final sdk = FirebaseNativeAuthSdk(
        appleBackendFactory: (_) => pending.future,
        platform: TargetPlatform.iOS,
        isWeb: false,
      );
      final operation = sdk.deleteAppleIdentity(
        config,
        validateIdentity: (_) async => true,
        isCurrentAccount: () => true,
      );
      final assertion = expectLater(operation, throwsA(sdkError('cancelled')));
      await sdk.cancel();
      pending.complete(backend);
      await assertion;
      expect(backend.calls, isEmpty);
    },
  );

  for (final cancelled in [false, true]) {
    test(
      'late ${cancelled ? 'cancel' : 'account switch'} during cleanup cannot confirm a stale screen',
      () async {
        final backend = DeletionBackend();
        final sdk = sdkFor(backend);
        final entered = Completer<void>();
        final release = Completer<void>();
        var current = true;
        backend.onSignOut = () async {
          entered.complete();
          await release.future;
        };
        final operation = sdk.deleteAppleIdentity(
          config,
          validateIdentity: (_) async => true,
          isCurrentAccount: () => current,
        );
        final assertion = expectLater(
          operation,
          throwsA(sdkError(cancelled ? 'cancelled' : 'account-changed')),
        );
        await entered.future;
        if (cancelled) {
          await sdk.cancel();
        } else {
          current = false;
        }
        release.complete();
        await assertion;
        // The remote mutation has completed; the caller must recover its receipt.
        expect(backend.calls, ['authenticate', 'revoke', 'delete', 'signOut']);
      },
    );
  }

  test(
    'duplicate confirmation does not cancel the accepted operation',
    () async {
      final backend = DeletionBackend();
      final sdk = sdkFor(backend);
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
      await expectLater(
        sdk.deleteAppleIdentity(
          config,
          validateIdentity: (_) async => true,
          isCurrentAccount: () => true,
        ),
        throwsA(sdkError('operation-in-progress')),
      );
      release.complete(true);
      await first;
      expect(backend.calls, ['authenticate', 'revoke', 'delete', 'signOut']);
    },
  );

  for (final stage in ['authenticate', 'validate', 'revoke', 'delete']) {
    test(
      '$stage failure is sanitized and a retry obtains a fresh proof',
      () async {
        final backend = DeletionBackend();
        final sdk = sdkFor(backend);
        Future<void> fail() async =>
            throw StateError('private upstream detail');
        if (stage == 'authenticate') backend.onAuthenticate = fail;
        if (stage == 'revoke') backend.onRevoke = fail;
        if (stage == 'delete') backend.onDelete = fail;
        await expectLater(
          sdk.deleteAppleIdentity(
            config,
            validateIdentity: (_) async {
              if (stage == 'validate') await fail();
              return true;
            },
            isCurrentAccount: () => true,
          ),
          throwsA(sdkError('identity-provider-unavailable')),
        );
        expect(backend.calls.last, 'signOut');
        if (stage != 'delete') expect(backend.calls, isNot(contains('delete')));
        backend.calls.clear();
        backend.onAuthenticate = backend.onRevoke = backend.onDelete = null;
        backend.token = 'new-proof-on-retry';
        await sdk.deleteAppleIdentity(
          config,
          validateIdentity: (token) async {
            expect(token, 'new-proof-on-retry');
            return true;
          },
          isCurrentAccount: () => true,
        );
        expect(backend.calls, ['authenticate', 'revoke', 'delete', 'signOut']);
      },
    );
  }

  test(
    'provider cancellation is reported safely and does not revoke',
    () async {
      final backend = DeletionBackend()
        ..onAuthenticate = () async => throw FirebaseAuthException(
          code: 'web-context-cancelled',
          message: 'private',
        );
      await expectLater(
        sdkFor(backend).deleteAppleIdentity(
          config,
          validateIdentity: (_) async => true,
          isCurrentAccount: () => true,
        ),
        throwsA(sdkError('cancelled')),
      );
      expect(backend.calls, ['authenticate', 'signOut']);
    },
  );

  test(
    'deletion is iOS only and does not change normal Apple sign-in',
    () async {
      final backend = DeletionBackend();
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        final sdk = FirebaseNativeAuthSdk(
          appleBackendFactory: (_) async => backend,
          platform: platform,
          isWeb: platform == TargetPlatform.iOS,
        );
        await expectLater(
          sdk.deleteAppleIdentity(
            config,
            validateIdentity: (_) async => true,
            isCurrentAccount: () => true,
          ),
          throwsA(sdkError('native-platform-required')),
        );
      }
      expect(backend.calls, isEmpty);
      final proof = await sdkFor(backend).apple(config);
      expect(proof.name, 'Customer');
      expect(backend.calls, ['normal-login']);
    },
  );
}
