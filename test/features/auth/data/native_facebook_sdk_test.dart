import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_sdk.dart';

const _appId = '123456789';
const _config = <String, dynamic>{
  'facebook': {'app_id': _appId, 'client_token': 'public-fixture-token'},
};
final _nonce = 'a' * 64;

Matcher _error(String code) => isA<NativeAuthSdkException>().having(
  (error) => error.code,
  'safe error code',
  code,
);

FirebaseNativeAuthSdk _sdk(
  _Backend backend, {
  TargetPlatform platform = TargetPlatform.android,
  bool isWeb = false,
  String appId = _appId,
}) => FirebaseNativeAuthSdk(
  platform: platform,
  isWeb: isWeb,
  facebookBackend: backend,
  facebookAppId: appId,
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      'Facebook $platform forwards the compiled app identity and server nonce',
      () async {
        final limited = platform == TargetPlatform.iOS;
        final backend = _Backend();
        backend.issue = () async =>
            NativeFacebookProof('fixture-proof', limited: limited);
        final sdk = _sdk(backend, platform: platform);
        final proof = await sdk.facebook(_config, nonce: _nonce);
        expect(backend.appId, _appId);
        expect(backend.nonce, _nonce);
        expect(backend.limited, limited);
        expect(proof.token, 'fixture-proof');
        expect(proof.limited, limited);
        await sdk.cancel();
      },
    );

    test('Facebook $platform rejects the other platform token kind', () async {
      final backend = _Backend();
      backend.issue = () async => NativeFacebookProof(
        'wrong-kind',
        limited: platform != TargetPlatform.iOS,
      );
      await expectLater(
        _sdk(backend, platform: platform).facebook(_config, nonce: _nonce),
        throwsA(_error('invalid-facebook-proof')),
      );
    });
  }

  for (final appId in ['', 'not-an-app-id', '012345', '9' * 65, '987654321']) {
    test(
      'Facebook rejects ${appId.isEmpty ? 'absent' : 'invalid or mismatched $appId'} compiled app identity',
      () async {
        final backend = _Backend();
        await expectLater(
          _sdk(backend, appId: appId).facebook(_config, nonce: _nonce),
          throwsA(_error('facebook-native-registration-required')),
        );
        expect(backend.calls, 0);
      },
    );
  }

  for (final config in <Map<String, dynamic>>[
    {},
    {'facebook': null},
    {'facebook': 'invalid'},
    {'facebook': {}},
    {
      'facebook': {'app_id': 123456789},
    },
    {
      'facebook': {'app_id': '987654321'},
    },
  ]) {
    test(
      'Facebook rejects missing or mismatched merchant identity: $config',
      () async {
        final backend = _Backend();
        await expectLater(
          _sdk(backend).facebook(config, nonce: _nonce),
          throwsA(_error('facebook-native-registration-required')),
        );
        expect(backend.calls, 0);
      },
    );
  }

  for (final nonce in ['', 'a' * 63, 'z' * 64, 'a' * 65]) {
    test(
      'Facebook rejects malformed server nonce length ${nonce.length}',
      () async {
        final backend = _Backend();
        await expectLater(
          _sdk(backend).facebook(_config, nonce: nonce),
          throwsA(_error('facebook-native-registration-required')),
        );
        expect(backend.calls, 0);
      },
    );
  }

  test(
    'Facebook rejects web and desktop before opening the provider',
    () async {
      for (final platform in [
        TargetPlatform.iOS,
        TargetPlatform.windows,
        TargetPlatform.macOS,
      ]) {
        final backend = _Backend();
        await expectLater(
          _sdk(
            backend,
            platform: platform,
            isWeb: platform == TargetPlatform.iOS,
          ).facebook(_config, nonce: _nonce),
          throwsA(_error('native-platform-required')),
        );
        expect(backend.calls, 0);
      }
    },
  );

  test('Facebook rejects an empty provider token', () async {
    final backend = _Backend();
    backend.issue = () async => const NativeFacebookProof('', limited: false);
    await expectLater(
      _sdk(backend).facebook(_config, nonce: _nonce),
      throwsA(_error('invalid-facebook-proof')),
    );
  });

  test(
    'Facebook cancellation discards a late account chooser response',
    () async {
      final backend = _Backend();
      final pending = Completer<NativeFacebookProof>();
      backend.issue = () => pending.future;
      final sdk = _sdk(backend);
      final result = sdk.facebook(_config, nonce: _nonce);
      final failure = expectLater(result, throwsA(_error('cancelled')));
      expect(backend.calls, 1);
      await sdk.cancel();
      pending.complete(const NativeFacebookProof('late-proof', limited: false));
      await failure;
    },
  );

  test('A new Facebook attempt invalidates an earlier pending proof', () async {
    final backend = _Backend();
    final pending = Completer<NativeFacebookProof>();
    backend.issue = () => pending.future;
    final sdk = _sdk(backend);
    final first = sdk.facebook(_config, nonce: _nonce);
    final failure = expectLater(first, throwsA(_error('cancelled')));
    backend.issue = () async =>
        const NativeFacebookProof('replacement-proof', limited: false);
    final second = await sdk.facebook(_config, nonce: 'b' * 64);
    pending.complete(const NativeFacebookProof('stale-proof', limited: false));
    await failure;
    expect(second.token, 'replacement-proof');
    expect(backend.nonce, 'b' * 64);
  });

  test(
    'Facebook preserves cancellation and sanitizes unexpected provider errors',
    () async {
      final backend = _Backend();
      backend.issue = () async =>
          throw const NativeAuthSdkException('cancelled');
      final sdk = _sdk(backend);
      await expectLater(
        sdk.facebook(_config, nonce: _nonce),
        throwsA(_error('cancelled')),
      );
      backend.issue = () async =>
          throw StateError('synthetic-private-provider-detail');
      await expectLater(
        sdk.facebook(_config, nonce: _nonce),
        throwsA(_error('identity-provider-unavailable')),
      );
    },
  );
}

class _Backend implements NativeFacebookBackend {
  int calls = 0;
  String? appId;
  String? nonce;
  bool? limited;
  Future<NativeFacebookProof> Function() issue = () async =>
      const NativeFacebookProof('fixture-proof', limited: false);

  @override
  Future<NativeFacebookProof> authenticate({
    required String appId,
    required String nonce,
    required bool limited,
  }) {
    calls++;
    this.appId = appId;
    this.nonce = nonce;
    this.limited = limited;
    return issue();
  }
}
