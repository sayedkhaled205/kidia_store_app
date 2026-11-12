import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_sdk.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_service.dart';
import 'package:mobishop_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:mobishop_store_app/features/auth/data/storage/last_login_method_store.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/repositories/auth_repository.dart';

const _facebook = {
  'app_id': '123456789',
  'client_token': 'public-fixture-token',
};
const _config = {
  'version': 1,
  'enabled': true,
  'methods': {'facebook_native': true},
  'facebook': _facebook,
};

Map<String, dynamic> _challenge() => {
  'ticket': 'a' * 64,
  'nonce': 'b' * 64,
  'expires_in': 300,
};

Map<String, dynamic> _session() => {
  'status': 'authenticated',
  'token': 'kma1.7.${'c' * 64}',
  'expires_at': DateTime.now()
      .toUtc()
      .add(const Duration(hours: 1))
      .toIso8601String(),
  'user': {'id': 7, 'email': 'fixture@example.com', 'display_name': 'Fixture'},
};

Matcher _failure([String? code]) => code == null
    ? isA<AuthRepositoryException>()
    : isA<AuthRepositoryException>().having(
        (error) => error.code,
        'code',
        code,
      );

Future<void> _until(bool Function() ready) async {
  final watch = Stopwatch()..start();
  while (!ready()) {
    if (watch.elapsed > const Duration(seconds: 2)) {
      fail('Expected operation did not start.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

Future<void> _flush() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  for (final platform in ['android', 'ios']) {
    test(
      'Facebook $platform exchanges one proof with the challenge verifier and commits once',
      () async {
        final h = _Harness(platform: platform);
        final result = await h.service.facebook();
        final challenge = h.posts('facebook/challenge').single;
        final exchange = h.posts('facebook').single;
        final field = platform == 'ios' ? 'id_token' : 'access_token';
        expect(
          challenge.uri.toString(),
          'https://shop.example/store/wp-json/mobishop/v1/auth/native/facebook/challenge',
        );
        expect(
          challenge.data.keys,
          unorderedEquals([
            'platform',
            if (platform == 'ios') 'ios_phone_callback_version',
            'verifier',
          ]),
        );
        expect(challenge.data['platform'], platform);
        expect(challenge.data['verifier'], matches(r'^[a-f0-9]{64}$'));
        expect(
          exchange.uri.toString(),
          'https://shop.example/store/wp-json/mobishop/v1/auth/native/facebook',
        );
        expect(
          exchange.data.keys,
          unorderedEquals([
            'platform',
            if (platform == 'ios') 'ios_phone_callback_version',
            'verifier',
            'ticket',
            field,
          ]),
        );
        expect(exchange.data['platform'], platform);
        expect(exchange.data['verifier'], challenge.data['verifier']);
        expect(exchange.data['ticket'], _challenge()['ticket']);
        expect(exchange.data[field], 'fixture-facebook-proof');
        expect(h.sdk.nonce, _challenge()['nonce']);
        expect(h.sdk.configuration!['facebook'], _facebook);
        expect(h.store.writes, 0);
        expect(h.remembered, isEmpty);
        expect(h.committed, isEmpty);
        await Future.wait([h.service.commit(result), h.service.commit(result)]);
        expect(h.store.writes, 1);
        expect(h.remembered, [LastLoginMethod.facebook]);
        expect(h.committed, [result.session]);
      },
    );
  }

  for (final entry in <String, Map<String, dynamic>>{
    'missing ticket': {..._challenge()}..remove('ticket'),
    'short ticket': {..._challenge(), 'ticket': 'a' * 63},
    'non-string ticket': {..._challenge(), 'ticket': 7},
    'missing nonce': {..._challenge()}..remove('nonce'),
    'non-hex nonce': {..._challenge(), 'nonce': 'z' * 64},
    'non-string nonce': {..._challenge(), 'nonce': 7},
    'missing expiry': {..._challenge()}..remove('expires_in'),
    'string expiry': {..._challenge(), 'expires_in': '300'},
    'zero expiry': {..._challenge(), 'expires_in': 0},
    'excess expiry': {..._challenge(), 'expires_in': 301},
  }.entries) {
    test('Facebook rejects ${entry.key} before opening the provider', () async {
      final h = _Harness()..challenge = entry.value;
      await expectLater(h.service.facebook(), throwsA(_failure()));
      expect(h.sdk.calls, 0);
      expect(h.posts('facebook'), isEmpty);
      expect(h.store.writes, 0);
      expect(h.remembered, isEmpty);
    });
  }

  test(
    'Disabled native Facebook does not request a challenge or launch an SDK',
    () async {
      final h = _Harness()
        ..configuration = {
          ..._config,
          'methods': {'facebook': true},
        };
      await expectLater(h.service.facebook(), throwsA(_failure()));
      expect(h.posts('facebook/challenge'), isEmpty);
      expect(h.sdk.calls, 0);
    },
  );

  for (final proof in [
    const NativeFacebookProof('', limited: false),
    const NativeFacebookProof('wrong-platform-proof', limited: true),
  ]) {
    test(
      'Android refuses ${proof.limited ? 'Limited Login' : 'empty'} proof before exchange',
      () async {
        final h = _Harness();
        h.sdk.issue = () async => proof;
        await expectLater(h.service.facebook(), throwsA(_failure()));
        expect(h.posts('facebook'), isEmpty);
        expect(h.store.writes, 0);
      },
    );
  }

  test('SDK cancellation never submits a Facebook credential or remembers a method', () async {
    final h = _Harness();
    h.sdk.issue = () async => throw const NativeAuthSdkException('cancelled');
    await expectLater(h.service.facebook(), throwsA(_failure('cancelled')));
    expect(h.posts('facebook'), isEmpty);
    expect(h.store.writes, 0);
    expect(h.remembered, isEmpty);
  });

  test('Cancelling during the challenge ignores its late response', () async {
    final h = _Harness();
    final pending = Completer<Response<dynamic>>();
    h.handler = (_) => pending.future;
    final failure = expectLater(
      h.service.facebook(),
      throwsA(_failure('cancelled')),
    );
    await _until(() => h.posts('facebook/challenge').isNotEmpty);
    await h.service.cancel();
    await failure;
    pending.complete(
      h.response(h.posts('facebook/challenge').single, _challenge()),
    );
    await _flush();
    expect(h.sdk.calls, 0);
    expect(h.posts('facebook'), isEmpty);
    expect(h.store.writes, 0);
  });

  test(
    'Cancelling a pending account chooser ignores its late Facebook proof',
    () async {
      final h = _Harness();
      final pending = Completer<NativeFacebookProof>();
      h.sdk.issue = () => pending.future;
      final failure = expectLater(
        h.service.facebook(),
        throwsA(_failure('cancelled')),
      );
      await _until(() => h.sdk.calls == 1);
      await h.service.cancel();
      await failure;
      pending.complete(const NativeFacebookProof('late-proof', limited: false));
      await _flush();
      expect(h.posts('facebook'), isEmpty);
      expect(h.store.writes, 0);
      expect(h.remembered, isEmpty);
    },
  );

  test(
    'Cancelling a pending exchange cannot persist its late merchant session',
    () async {
      final h = _Harness();
      final pending = Completer<Response<dynamic>>();
      h.handler = (request) => request.uri.path.endsWith('/facebook')
          ? pending.future
          : Future.value(h.response(request, _challenge()));
      final failure = expectLater(
        h.service.facebook(),
        throwsA(_failure('cancelled')),
      );
      await _until(() => h.posts('facebook').isNotEmpty);
      await h.service.cancel();
      await failure;
      pending.complete(h.response(h.posts('facebook').single, _session()));
      await _flush();
      expect(h.store.writes, 0);
      expect(h.remembered, isEmpty);
      expect(h.committed, isEmpty);
    },
  );

  test('Cancelling after the exchange rejects a provisional Facebook session commit', () async {
    final h = _Harness();
    final result = await h.service.facebook();
    await h.service.cancel();
    await expectLater(h.service.commit(result), throwsA(_failure('cancelled')));
    expect(h.store.writes, 0);
    expect(h.remembered, isEmpty);
  });

  test('A replacement Facebook attempt owns a fresh verifier and the only committable result', () async {
    final h = _Harness();
    final first = await h.service.facebook();
    final second = await h.service.facebook();
    expect(
      h.posts('facebook/challenge').map((r) => r.data['verifier']).toSet(),
      hasLength(2),
    );
    await expectLater(h.service.commit(first), throwsA(_failure('cancelled')));
    await h.service.commit(second);
    expect(h.store.writes, 1);
    expect(h.remembered, [LastLoginMethod.facebook]);
  });

  for (final status in ['select_account', 'registration_required']) {
    test(
      'Facebook $status preserves its verifier and method until final commit',
      () async {
        final h = _Harness();
        final ticket = 'd' * 64;
        h.handler = (request) async => h.response(
          request,
          request.uri.path.endsWith('/facebook/challenge')
              ? _challenge()
              : request.uri.path.endsWith('/facebook')
              ? {
                  'status': status,
                  'ticket': ticket,
                  'expires_in': 300,
                  if (status == 'select_account')
                    'accounts': [
                      {'id': 7, 'name': 'Fixture'},
                    ],
                  if (status == 'registration_required') 'fields': ['name'],
                }
              : _session(),
        );
        final continuation = await h.service.facebook();
        await expectLater(h.service.commit(continuation), throwsA(_failure()));
        expect(h.store.writes, 0);
        final result = status == 'select_account'
            ? await h.service.selectAccount(continuation.ticket, 7)
            : await h.service.register(
                continuation.ticket,
                name: 'Fixture',
                password: '',
              );
        final completion = h
            .posts(status == 'select_account' ? 'select' : 'register')
            .single;
        expect(completion.data['ticket'], ticket);
        expect(
          completion.data['verifier'],
          h.posts('facebook').single.data['verifier'],
        );
        expect(h.store.writes, 0);
        await h.service.commit(result);
        expect(h.remembered, [LastLoginMethod.facebook]);
      },
    );
  }
}

class _Harness {
  _Harness({String platform = 'android'})
    : sdk = _Sdk(limited: platform == 'ios') {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, callback) async {
          requests.add(request);
          if (request.uri.path.endsWith('/config')) {
            callback.resolve(response(request, configuration));
          } else if (handler != null) {
            callback.resolve(await handler!(request));
          } else {
            callback.resolve(
              response(
                request,
                request.uri.path.endsWith('/facebook/challenge')
                    ? challenge
                    : _session(),
              ),
            );
          }
        },
      ),
    );
    service = NativeAuthService(
      storeUri: Uri.parse('https://shop.example/store/'),
      dio: dio,
      sdk: sdk,
      sessionStore: store,
      platform: platform,
      rememberMethod: (method) async {
        remembered.add(method);
      },
      onCommitted: (session) async {
        committed.add(session);
      },
    );
  }

  final dio = Dio();
  final _Sdk sdk;
  final store = _Store();
  final requests = <RequestOptions>[];
  final remembered = <LastLoginMethod>[];
  final committed = <AuthSession>[];
  Map<String, dynamic> configuration = {..._config};
  Map<String, dynamic> challenge = _challenge();
  Future<Response<dynamic>> Function(RequestOptions)? handler;
  late final NativeAuthService service;

  Response<dynamic> response(RequestOptions request, Object? data) =>
      Response(requestOptions: request, statusCode: 200, data: data);
  List<RequestOptions> posts(String action) => requests
      .where((r) => r.method == 'POST' && r.uri.path.endsWith('/$action'))
      .toList();
}

class _Sdk implements NativeAuthSdk, NativeFacebookAuthSdk {
  _Sdk({required bool limited}) {
    issue = () async =>
        NativeFacebookProof('fixture-facebook-proof', limited: limited);
  }
  int calls = 0;
  String? nonce;
  Map<String, dynamic>? configuration;
  late Future<NativeFacebookProof> Function() issue;

  @override
  Future<NativeFacebookProof> facebook(
    Map<String, dynamic> config, {
    required String nonce,
  }) {
    calls++;
    configuration = config;
    this.nonce = nonce;
    return issue();
  }

  @override
  Future<void> cancel() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store extends MemoryAuthSessionStore {
  int writes = 0;
  @override
  Future<void> write(AuthSession session) async {
    writes++;
    await super.write(session);
  }
}
