import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_sdk.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_service.dart';
import 'package:mobishop_store_app/features/auth/data/network/auth_api_transport.dart';
import 'package:mobishop_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_identity.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/native_auth.dart';
import 'package:mobishop_store_app/features/auth/domain/repositories/auth_repository.dart';

const _configuration = {
  'version': 1,
  'enabled': true,
  'methods': {
    'password': true,
    'email_password': true,
    'phone_password': true,
    'phone_otp': true,
    'google': true,
    'registration': true,
  },
  'firebase': {'projectId': 'merchant-fixture'},
  'google': {'server_client_id': 'fixture.apps.googleusercontent.com'},
};

Map<String, dynamic> _session() => {
  'status': 'authenticated',
  'token': 'kma1.7.${'a' * 64}',
  'expires_at': DateTime.now()
      .toUtc()
      .add(const Duration(hours: 1))
      .toIso8601String(),
  'user': {
    'id': 7,
    'email': 'customer@example.com',
    'display_name': 'Customer',
  },
};

Map<String, dynamic> _picker() => {
  'status': 'select_account',
  'ticket': 'b' * 64,
  'expires_in': 300,
  'accounts': [
    {'id': 7, 'name': 'First', 'email_hint': 'c***@example.com'},
    {'id': 9, 'name': 'Second'},
  ],
};

Map<String, dynamic> _registration({int ttl = 300}) => {
  'status': 'registration_required',
  'ticket': 'c' * 64,
  'expires_in': ttl,
  'fields': ['name', 'password', 'phone'],
};

final _failure = isA<AuthRepositoryException>();

Future<void> _flush() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _until(bool Function() ready) async {
  final watch = Stopwatch()..start();
  while (!ready()) {
    if (watch.elapsed > const Duration(seconds: 2)) {
      fail('Expected operation did not start.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  for (final type in [
    DioExceptionType.connectionError,
    DioExceptionType.unknown,
    DioExceptionType.connectionTimeout,
    DioExceptionType.sendTimeout,
    DioExceptionType.receiveTimeout,
    DioExceptionType.transformTimeout,
    DioExceptionType.badCertificate,
  ]) {
    for (final stage in ['config', 'identify']) {
      test(
        '$stage $type remains retryable without an authentication downgrade',
        () async {
          final h = _Harness();
          var attempts = 0;
          var unavailable = true;
          h.dio.interceptors.insert(
            0,
            InterceptorsWrapper(
              onRequest: (request, callback) {
                if (request.uri.path.endsWith('/$stage')) {
                  attempts++;
                  if (unavailable) {
                    callback.reject(
                      DioException(
                        requestOptions: request,
                        type: type,
                        message: 'private network diagnostics',
                      ),
                    );
                    return;
                  }
                }
                callback.next(request);
              },
            ),
          );
          h.handler = (request) async => h.response(request, {
            'identifier': 'customer@example.com',
            'kind': 'email',
            'methods': ['password'],
          });
          final expectedKind = switch (type) {
            DioExceptionType.badCertificate => AuthFailureKind.certificate,
            DioExceptionType.connectionTimeout ||
            DioExceptionType.sendTimeout ||
            DioExceptionType.receiveTimeout ||
            DioExceptionType.transformTimeout => AuthFailureKind.timeout,
            _ => AuthFailureKind.connection,
          };
          final expectedMessage = switch (expectedKind) {
            AuthFailureKind.certificate => contains('شهادة أمان'),
            AuthFailureKind.timeout => contains('وقت أطول'),
            _ => contains('راجع الإنترنت'),
          };
          await expectLater(
            h.service.identify('customer@example.com'),
            throwsA(
              _failure
                  .having((e) => e.kind, 'kind', expectedKind)
                  .having(
                    (e) => e.message,
                    'actionable message',
                    expectedMessage,
                  )
                  .having(
                    (e) => e.message,
                    'safe message',
                    isNot(contains('private')),
                  ),
            ),
          );
          expect(attempts, 1);
          expect(h.store.writes, 0);
          expect(h.sdk.googleCalls, 0);
          expect(h.sdk.challenges, isEmpty);
          expect(h.legacy.identifications, 0);

          unavailable = false;
          final identity = await h.service.identify('customer@example.com');
          expect(identity.methods, ['password']);
          expect(attempts, 2);
          expect(h.store.writes, 0);
        },
      );
    }
  }

  test(
    'known connector failures keep safe reason codes without exposing server text',
    () async {
      final h = _Harness();
      h.handler = (request) async => h.response(request, {
        'code': 'mobishop_native_additional_proof_required',
        'message': 'private server data must never be shown',
      }, status: 403);
      await expectLater(
        h.service.google(),
        throwsA(
          _failure
              .having(
                (e) => e.code,
                'code',
                'mobishop_native_additional_proof_required',
              )
              .having(
                (e) => e.message,
                'safe message',
                isNot(contains('private server data')),
              ),
        ),
      );
      expect(h.store.writes, 0);
    },
  );

  test('SMS SDK quota and invalid-code errors remain actionable', () async {
    final h = _Harness();
    final challenge = await h.service.sendOtp('+201012345678');
    h.sdk.manual = () async =>
        throw const NativeAuthSdkException('quota-exceeded');
    await expectLater(
      h.service.verifyOtp(challenge, '123456'),
      throwsA(
        _failure
            .having((e) => e.kind, 'kind', AuthFailureKind.rateLimited)
            .having((e) => e.code, 'code', 'quota-exceeded'),
      ),
    );
    expect(h.store.writes, 0);
  });

  test(
    'fixed HTTPS merchant endpoints retain installation path and disable redirects',
    () async {
      final h = _Harness();
      await h.service.config();
      final request = h.requests.single;
      expect(request.uri.origin, 'https://shop.example');
      expect(request.uri.path, '/store/wp-json/mobishop/v1/auth/native/config');
      expect(request.uri.queryParameters['platform'], 'android');
      expect(request.followRedirects, isFalse);
      expect(request.maxRedirects, 0);
      for (final uri in [
        'http://shop.example',
        'https://user:password@shop.example',
        'https://shop.example?secret=bad',
      ]) {
        expect(
          () => NativeAuthService(
            storeUri: Uri.parse(uri),
            dio: Dio(),
            sdk: _Sdk(),
            sessionStore: _Store(),
          ),
          throwsA(_failure),
        );
      }
    },
  );

  test(
    'only config 404 enables the limited email legacy registration path',
    () async {
      final h = _Harness()..configStatus = 404;
      h.legacy.registered = false;
      final configuration = await h.service.config();
      expect(configuration.methods, {
        'email_password': true,
        'registration': true,
      });
      final identity = await h.service.identify('new@example.com');
      expect(identity.methods, ['create_password']);
      final result = await h.service.password(
        identity.identifier,
        'valid-password',
      );
      expect(result.status, NativeAuthStatus.authenticated);
      expect(h.legacy.registrations, 1);
      expect(h.legacy.signIns, 0);
      expect(h.store.writes, 0);
      expect(h.requests.length, 1);
      await expectLater(h.service.google(), throwsA(_failure));
      await expectLater(h.service.sendOtp('+201012345678'), throwsA(_failure));
      expect(h.sdk.googleCalls, 0);
      expect(h.sdk.challenges, isEmpty);
    },
  );

  for (final status in [302, 401, 500]) {
    test('config $status fails without legacy downgrade', () async {
      final h = _Harness()..configStatus = status;
      await expectLater(
        h.service.identify('customer@example.com'),
        throwsA(_failure),
      );
      expect(h.legacy.identifications, 0);
      expect(h.legacy.signIns, 0);
    });
  }

  test('a foreign-origin 404 cannot activate legacy fallback', () async {
    final h = _Harness()..configStatus = -1;
    h.handler = (request) async => Response(
      requestOptions: request.copyWith(path: 'https://other.example/anything'),
      statusCode: 404,
    );
    await expectLater(h.service.config(), throwsA(_failure));
    expect(h.legacy.identifications, 0);
  });

  test(
    'native errors never fall back and ignore unsafe server error text',
    () async {
      final h = _Harness();
      h.handler = (request) async => h.response(request, {
        'message': 'password=private-proof',
      }, status: 401);
      try {
        await h.service.password('customer@example.com', 'private-password');
        fail('Expected rejection');
      } on AuthRepositoryException catch (error) {
        expect(error.message, isNot(contains('private')));
      }
      expect(h.legacy.signIns, 0);
      expect(h.store.writes, 0);
    },
  );

  test(
    'password remains provisional; only its owned result commits once',
    () async {
      final h = _Harness();
      final result = await h.service.password(
        'customer@example.com',
        'valid-password',
      );
      expect(h.store.writes, 0);
      await Future.wait([h.service.commit(result), h.service.commit(result)]);
      expect(h.store.writes, 1);
      await h.service.cancel();
      expect(h.store.value?.user.id, 7);
      await expectLater(h.service.commit(result), throwsA(_failure));
      await expectLater(
        h.service.commit(
          NativeAuthResult(
            status: NativeAuthStatus.authenticated,
            session: result.session,
          ),
        ),
        throwsA(_failure),
      );
      expect(h.store.writes, 1);
    },
  );

  test(
    'storage failure retries the same session without repeating its proof',
    () async {
      final h = _Harness()..store.failNext = true;
      final result = await h.service.password(
        'customer@example.com',
        'valid-password',
      );
      await expectLater(h.service.commit(result), throwsA(_failure));
      await h.service.commit(result);
      expect(h.store.writes, 2);
      expect(h.posts('password').length, 1);
    },
  );

  test(
    'post-commit notification runs after storage once and cannot undo success',
    () async {
      late _Harness h;
      var notifications = 0;
      h = _Harness(
        onCommitted: (session) async {
          notifications++;
          expect(h.store.value, same(session));
          throw StateError('Analytics unavailable');
        },
      );
      final result = await h.service.password(
        'customer@example.com',
        'valid-password',
      );
      await h.service.commit(result);
      await h.service.commit(result);
      expect(notifications, 1);
      expect(h.store.writes, 1);
      expect(h.store.value?.user.id, 7);
    },
  );

  test(
    'cancel resolves a pending request immediately and rejects its late result',
    () async {
      final h = _Harness();
      final pending = Completer<Response<dynamic>>();
      h.handler = (request) => pending.future;
      final result = h.service.password(
        'customer@example.com',
        'valid-password',
      );
      final rejected = expectLater(result, throwsA(_failure));
      await _until(() => h.posts('password').isNotEmpty);
      final oldRequest = h.posts('password').single;
      await h.service.cancel();
      await rejected;
      pending.complete(h.response(oldRequest, _session()));
      await _flush();
      expect(h.store.writes, 0);
      h.handler = null;
      await h.service.password('customer@example.com', 'valid-password');
      expect(
        h.posts('password').last.data['verifier'],
        isNot(oldRequest.data['verifier']),
      );
    },
  );

  test(
    'a new password attempt invalidates the prior provisional result',
    () async {
      final h = _Harness();
      final first = await h.service.password(
        'customer@example.com',
        'valid-password',
      );
      final second = await h.service.password(
        'customer@example.com',
        'valid-password',
      );
      await expectLater(h.service.commit(first), throwsA(_failure));
      await h.service.commit(second);
      expect(h.store.writes, 1);
      expect(
        h.posts('password').first.data['verifier'],
        matches(RegExp(r'^[a-f0-9]{64}$')),
      );
    },
  );

  test(
    'phone proof picker and selection preserve the verifier and restrict choices',
    () async {
      final h = _Harness();
      h.handler = (request) async => h.response(
        request,
        request.uri.path.endsWith('phone/verify') ? _picker() : _session(),
      );
      final challenge = await h.service.sendOtp('+201012345678');
      final picker = await h.service.verifyOtp(challenge, '123456');
      await expectLater(
        h.service.selectAccount(picker.ticket, 99),
        throwsA(_failure),
      );
      expect(h.posts('select'), isEmpty);
      final result = await h.service.selectAccount(picker.ticket, 7);
      expect(result.status, NativeAuthStatus.authenticated);
      expect(
        h.posts('phone/verify').single.data['verifier'],
        h.posts('select').single.data['verifier'],
      );
      expect(h.store.writes, 0);
      await h.service.commit(result);
      expect(h.store.writes, 1);
    },
  );

  test(
    'automatic and manual SMS results share one backend submission',
    () async {
      final h = _Harness();
      final manual = Completer<String>();
      h.sdk.manual = () => manual.future;
      final challenge = await h.service.sendOtp('+201012345678');
      final verified = h.service.verifyOtp(challenge, '123456');
      h.sdk.automatic.last.complete('automatic-proof');
      await _flush();
      manual.complete('manual-proof');
      final results = await Future.wait([verified, challenge.automaticResult]);
      expect(identical(results[0], results[1]), isTrue);
      expect(h.posts('phone/verify').length, 1);
      final repeat = await h.service.verifyOtp(challenge, '123456');
      expect(identical(repeat, results[0]), isTrue);
      expect(h.posts('phone/verify').length, 1);
    },
  );

  test(
    'wrong SMS code remains retryable without exchanging an invalid proof',
    () async {
      final h = _Harness();
      h.sdk.manual = () async =>
          throw const NativeAuthSdkException('invalid-verification-code');
      final challenge = await h.service.sendOtp('+201012345678');
      await expectLater(
        h.service.verifyOtp(challenge, '000000'),
        throwsA(_failure),
      );
      expect(h.posts('phone/verify'), isEmpty);
      h.sdk.manual = null;
      await h.service.verifyOtp(challenge, '123456');
      expect(h.posts('phone/verify').length, 1);
    },
  );

  test('late automatic proof from a resent SMS cannot commit', () async {
    final h = _Harness();
    final pending = Completer<Response<dynamic>>();
    h.handler = (request) => pending.future;
    final first = await h.service.sendOtp('+201012345678');
    final rejected = expectLater(first.automaticResult, throwsA(_failure));
    h.sdk.automatic.last.complete('old-proof');
    await _until(() => h.posts('phone/verify').isNotEmpty);
    final request = h.posts('phone/verify').single;
    final second = await h.service.sendOtp('+201012345678', resend: first);
    pending.complete(h.response(request, _session()));
    await rejected;
    expect(h.store.writes, 0);
    h.handler = null;
    await h.service.commit(await h.service.verifyOtp(second, '123456'));
    expect(h.store.writes, 1);
    expect(h.sdk.resendTokens.last, first.resendToken);
  });

  test(
    'Google completion carries the same verifier through phone proof and registration',
    () async {
      final h = _Harness();
      h.handler = (request) async => h.response(
        request,
        request.uri.path.endsWith('/register') ? _session() : _registration(),
      );
      final google = await h.service.google();
      final challenge = await h.service.sendOtp(
        '+201012345678',
        ticket: google.ticket,
      );
      final proved = await h.service.verifyOtp(
        challenge,
        '123456',
        ticket: google.ticket,
      );
      final result = await h.service.register(
        proved.ticket,
        name: 'Customer',
        password: 'valid-password',
      );
      expect(result.status, NativeAuthStatus.authenticated);
      final posts = [
        h.posts('google').single,
        h.posts('phone/verify').single,
        h.posts('register').single,
      ];
      expect(posts.map((r) => r.data['verifier']).toSet().length, 1);
      expect(posts[1].data['ticket'], google.ticket);
      expect(posts[2].data.containsKey('email'), isFalse);
      expect(h.store.writes, 0);
    },
  );

  test('selection double tap submits a one-use ticket once', () async {
    final h = _Harness();
    final pending = Completer<Response<dynamic>>();
    h.handler = (request) => request.uri.path.endsWith('/select')
        ? pending.future
        : Future.value(h.response(request, _picker()));
    final challenge = await h.service.sendOtp('+201012345678');
    final picker = await h.service.verifyOtp(challenge, '123456');
    final one = h.service.selectAccount(picker.ticket, 7);
    final two = h.service.selectAccount(picker.ticket, 7);
    await _until(() => h.posts('select').isNotEmpty);
    expect(h.posts('select').length, 1);
    pending.complete(h.response(h.posts('select').single, _session()));
    expect(identical((await Future.wait([one, two]))[0], await one), isTrue);
  });

  test('expired continuation is rejected locally', () async {
    final h = _Harness();
    h.handler = (request) async => h.response(request, _registration(ttl: 1));
    final result = await h.service.google();
    await Future<void>.delayed(const Duration(milliseconds: 1050));
    await expectLater(
      h.service.register(
        result.ticket,
        name: 'Customer',
        password: 'valid-password',
      ),
      throwsA(_failure),
    );
    expect(h.posts('register'), isEmpty);
  });
}

class _Harness {
  _Harness({Future<void> Function(AuthSession)? onCommitted}) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, callback) async {
          requests.add(request);
          if (request.uri.path.endsWith('/config')) {
            if (handler != null && configStatus == -1) {
              callback.resolve(await handler!(request));
              return;
            }
            callback.resolve(
              response(request, _configuration, status: configStatus),
            );
          } else {
            callback.resolve(
              handler == null
                  ? response(request, _session())
                  : await handler!(request),
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
      legacyTransport: legacy,
      onCommitted: onCommitted,
      platform: 'android',
    );
  }
  final dio = Dio();
  final sdk = _Sdk();
  final store = _Store();
  final legacy = _Legacy();
  final requests = <RequestOptions>[];
  int configStatus = 200;
  Future<Response<dynamic>> Function(RequestOptions)? handler;
  late final NativeAuthService service;
  Response<dynamic> response(
    RequestOptions request,
    Object? data, {
    int status = 200,
  }) => Response(requestOptions: request, statusCode: status, data: data);
  List<RequestOptions> posts(String action) => requests
      .where((r) => r.uri.path.endsWith('/$action') && r.method == 'POST')
      .toList();
}

class _Sdk implements NativeAuthSdk {
  final automatic = <Completer<String?>>[];
  final challenges = <NativePhoneChallenge>[];
  final resendTokens = <int?>[];
  Future<String> Function()? manual;
  int googleCalls = 0;
  @override
  Future<void> cancel() async {}
  @override
  Future<String> google(Map<String, dynamic> config) async {
    googleCalls++;
    return 'google-proof';
  }

  @override
  Future<NativePhoneChallenge> startPhone({
    required Map<String, dynamic> config,
    required String phone,
    int? resendToken,
  }) async {
    resendTokens.add(resendToken);
    final proof = Completer<String?>();
    automatic.add(proof);
    final challenge = NativePhoneChallenge(
      verificationId: 'fixture-${automatic.length}',
      resendToken: automatic.length,
      automaticIdToken: proof.future,
    );
    challenges.add(challenge);
    return challenge;
  }

  @override
  Future<String> verifyPhone(NativePhoneChallenge challenge, String code) =>
      manual?.call() ?? Future.value('phone-proof');
}

class _Store extends MemoryAuthSessionStore {
  int writes = 0;
  bool failNext = false;
  @override
  Future<void> write(AuthSession session) async {
    writes++;
    if (failNext) {
      failNext = false;
      throw StateError('Storage unavailable');
    }
    await super.write(session);
  }
}

class _Legacy implements AuthApiTransport {
  bool registered = true;
  int identifications = 0;
  int signIns = 0;
  int registrations = 0;
  @override
  Future<AuthIdentity> identify(String email) async {
    identifications++;
    return AuthIdentity(email: email, isRegistered: registered);
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    signIns++;
    return AuthSession.fromJson(_session());
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    registrations++;
    return AuthSession.fromJson(_session());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
