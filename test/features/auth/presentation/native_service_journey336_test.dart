// Real screen + service + session storage; only HTTP and platform proofs are fixtures.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_sdk.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_service.dart';
import 'package:mobishop_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/presentation/auth_screen.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/native_auth_providers.dart';

class _Auth extends AuthController {
  @override
  Future<AuthSession?> build() async => null;
  void publish(AuthSession session) => state = AsyncData(session);
}

class _Sdk implements NativeAuthSdk {
  @override
  Future<String> google(Map<String, dynamic> config) async => 'synthetic-proof';
  @override
  Future<void> cancel() async {}
  @override
  Future<NativePhoneChallenge> startPhone({
    required Map<String, dynamic> config,
    required String phone,
    int? resendToken,
  }) async => NativePhoneChallenge(verificationId: 'fixture-challenge');
  @override
  Future<String> verifyPhone(
    NativePhoneChallenge challenge,
    String code,
  ) async => 'synthetic-phone-proof';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final outcome in [
    'success',
    'timeout',
    'server',
    'expired',
    'busy',
    'limited',
    'enroll-timeout',
    'confirm-timeout',
    'verify-timeout',
    'conflict-existing',
    'conflict-different',
  ]) {
    testWidgets(
      'Google signup real service completes or recovers from $outcome',
      (tester) async {
        final dio = Dio();
        final store = MemoryAuthSessionStore();
        final auth = _Auth();
        var registrations = 0;
        var signIns = 0;
        var enrollments = 0;
        String? registrationVerifier;
        final requests = <RequestOptions>[];
        final session = <String, dynamic>{
          'status': 'authenticated',
          'token': 'kma1.7.${'a' * 64}',
          'expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(hours: 1))
              .toIso8601String(),
          'user': {
            'id': 7,
            'email': 'fixture@example.invalid',
            'display_name': 'Fixture',
          },
        };
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              requests.add(request);
              final action = request.uri.path.split('/').last;
              var status = 200;
              Object data;
              switch (action) {
                case 'config':
                  data = {
                    'version': 1,
                    'enabled': true,
                    'phone_country_code': '20',
                    'supports_unverified_phone_enrollment': true,
                    'methods': {
                      'google': true,
                      'email_password': true,
                      'phone_password': true,
                      'phone_otp':
                          outcome == 'verify-timeout' ||
                          outcome.startsWith('conflict-'),
                      'registration': true,
                    },
                  };
                case 'google':
                  signIns++;
                  data = signIns > 1
                      ? session
                      : {
                          'status': 'registration_required',
                          'ticket': 'b' * 64,
                          'expires_in': 300,
                          'fields': ['name', 'password', 'phone'],
                        };
                case 'enroll':
                case 'confirm':
                case 'verify':
                  if (outcome == '$action-timeout') {
                    handler.reject(
                      DioException(
                        requestOptions: request,
                        type: DioExceptionType.receiveTimeout,
                      ),
                    );
                    return;
                  }
                  if (action == 'enroll') enrollments++;
                  data = {
                    'status': 'registration_required',
                    'ticket':
                        (action == 'enroll'
                            ? (enrollments == 1 ? 'c' : 'e')
                            : (enrollments == 1 ? 'd' : 'f')) *
                        64,
                    'expires_in': 300,
                    'fields': [
                      'name',
                      'password',
                      if (action == 'enroll') 'phone',
                    ],
                  };
                case 'identify':
                  expect(request.data['verifier'], isNot(registrationVerifier));
                  expect(request.data.containsKey('ticket'), isFalse);
                  data = {
                    'identifier': '+201012345678',
                    'kind': 'phone',
                    'methods': ['password'],
                  };
                case 'password':
                  data = session;
                case 'register':
                  registrations++;
                  registrationVerifier = request.data['verifier'] as String;
                  if (outcome == 'timeout') {
                    handler.reject(
                      DioException(
                        requestOptions: request,
                        type: DioExceptionType.receiveTimeout,
                      ),
                    );
                    return;
                  }
                  status = registrations == 1
                      ? switch (outcome) {
                          'server' => 503,
                          'expired' => 401,
                          'busy' => 409,
                          'limited' => 429,
                          'conflict-existing' || 'conflict-different' => 409,
                          _ => 200,
                        }
                      : 200;
                  data = status == 200
                      ? session
                      : {
                          'code': outcome == 'expired'
                              ? 'mobishop_native_invalid_ticket'
                              : outcome == 'busy'
                              ? 'mobishop_native_retry'
                              : outcome.startsWith('conflict-')
                              ? 'mobishop_native_phone_account_conflict'
                              : 'temporary',
                        };
                default:
                  fail('Unexpected real service request: $action');
              }
              handler.resolve(
                Response(
                  requestOptions: request,
                  statusCode: status,
                  data: data,
                ),
              );
            },
          ),
        );
        final service = NativeAuthService(
          storeUri: Uri.parse('https://fixture.example.invalid'),
          dio: dio,
          sdk: _Sdk(),
          sessionStore: store,
          onCommitted: (s) async => auth.publish(s),
          rememberMethod: (_) async {},
          platform: 'ios',
        );
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
        addTearDown(() => dio.close());
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(() => auth),
              nativeAuthActionsProvider.overrideWithValue(service),
              nativeAuthConfigProvider.overrideWith((_) => service.config()),
              lastLoginMethodProvider.overrideWith((_) async => null),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        await _tap(tester, 'auth-google');
        Future<void> phone(String value) async {
          await tester.enterText(find.byKey(const Key('auth-phone')), value);
          await _tap(tester, 'auth-send-otp');
          if (find.byKey(const Key('auth-restart')).evaluate().isNotEmpty) {
            return;
          }
          if (find.byKey(const Key('auth-otp')).evaluate().isNotEmpty) {
            await tester.enterText(find.byKey(const Key('auth-otp')), '123456');
            await _tap(tester, 'auth-verify-otp');
          } else {
            await tester.enterText(find.byKey(const Key('auth-phone')), value);
            await _tap(tester, 'auth-send-otp');
          }
        }

        await phone('01012345678');
        if (outcome.endsWith('-timeout')) {
          expect(store.value, isNull);
          final before = requests
              .where((r) => r.uri.path.endsWith('/${outcome.split('-').first}'))
              .length;
          await _tap(tester, 'auth-restart');
          await _tap(tester, 'auth-google');
          expect(
            requests.where(
              (r) => r.uri.path.endsWith('/${outcome.split('-').first}'),
            ),
            hasLength(before),
          );
          expect(registrations, 0);
          expect(store.value?.user.id, 7);
          return;
        }
        await tester.enterText(find.byKey(const Key('auth-name')), 'Fixture');
        await tester.enterText(
          find.byKey(const Key('auth-create-password')),
          'fixture-password',
        );
        await tester.enterText(
          find.byKey(const Key('auth-confirm-password')),
          'fixture-password',
        );
        await _tap(tester, 'auth-register');
        if (['timeout', 'server', 'expired'].contains(outcome)) {
          expect(store.value, isNull);
          expect(find.byKey(const Key('auth-register')), findsNothing);
          await _tap(tester, 'auth-restart');
          expect(find.byKey(const Key('auth-email')), findsOneWidget);
          await _tap(tester, 'auth-google');
          expect(
            registrations,
            1,
            reason: 'An uncertain one-use registration must never replay.',
          );
        } else if (['busy', 'limited'].contains(outcome)) {
          expect(store.value, isNull);
          await _tap(tester, 'auth-register');
          expect(
            registrations,
            2,
            reason: 'A definite rejection must permit a fresh request.',
          );
        } else if (outcome.startsWith('conflict-')) {
          expect(store.value, isNull);
          expect(find.text('01012345678'), findsOneWidget);
          expect(
            find.byKey(const Key('auth-existing-phone-signin')),
            findsOneWidget,
          );
          expect(find.byKey(const Key('auth-different-phone')), findsOneWidget);
          if (outcome == 'conflict-existing') {
            await _tap(tester, 'auth-existing-phone-signin');
            expect(find.byKey(const Key('auth-use-password')), findsNothing);
            await tester.enterText(
              find.byKey(const Key('auth-password')),
              'existing-password',
            );
            await _tap(tester, 'auth-sign-in');
            expect(registrations, 1);
          } else {
            await _tap(tester, 'auth-different-phone');
            await phone('01012345679');
            await _tap(tester, 'auth-register');
            expect(registrations, 2);
            expect(enrollments, 2);
            final enroll = requests
                .where((r) => r.uri.path.endsWith('/enroll'))
                .last;
            expect(enroll.data['ticket'], 'd' * 64);
            expect(enroll.data['phone'], '+201012345679');
          }
        }
        expect(store.value?.user.id, 7);
        expect(find.text('SIGNED IN'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
