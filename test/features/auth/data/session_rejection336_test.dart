import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/auth/data/network/session_rejection_interceptor.dart';
import 'package:mobishop_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';

AuthSession _session(String token, {int seconds = 3600}) => AuthSession(
  token: token,
  expiresAt: DateTime.now().toUtc().add(Duration(seconds: seconds)),
  user: const AuthUser(id: 7, email: 'fixture@example.invalid'),
);

class _Repo implements AuthRepository {
  _Repo(this.session);
  final AuthSession session;
  @override
  Future<AuthSession?> restoreSession() async => session;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final rejection in [true, false]) {
    for (final entry in [
      (
        401,
        'mobishop_auth_unauthorized',
        'https://merchant.example',
        true,
        true,
      ),
      (
        401,
        'mobishop_native_checkout50_unauthorized',
        'https://merchant.example',
        true,
        true,
      ),
      (
        403,
        'mobishop_account_deletion_reauth',
        'https://merchant.example',
        true,
        false,
      ),
      (401, 'invalid_password', 'https://merchant.example', true, false),
      (
        500,
        'mobishop_auth_unauthorized',
        'https://merchant.example',
        true,
        false,
      ),
      (
        401,
        'mobishop_auth_unauthorized',
        'https://outside.example',
        true,
        false,
      ),
      (
        401,
        'mobishop_auth_unauthorized',
        'https://merchant.example',
        false,
        false,
      ),
    ]) {
      test('session rejection $entry error-handler=$rejection', () async {
        final invalidated = <String>[];
        final dio = Dio();
        addTearDown(dio.close);
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) {
              final response = Response(
                requestOptions: request,
                statusCode: entry.$1,
                data: jsonEncode({'code': entry.$2}),
              );
              if (rejection) {
                handler.reject(
                  DioException(
                    requestOptions: request,
                    response: response,
                    type: DioExceptionType.badResponse,
                  ),
                  true,
                );
              } else {
                handler.resolve(response, true);
              }
            },
          ),
        );
        dio.interceptors.add(
          SessionRejectionInterceptor(
            storeUri: Uri.parse('https://merchant.example'),
            onRejected: (token) async => invalidated.add(token),
          ),
        );
        try {
          await dio.get(
            '${entry.$3}/wp-json/mobishop/v1/account',
            options: Options(
              headers: {if (entry.$4) 'X-MobiShop-Session': 'fixture-old'},
            ),
          );
        } on DioException catch (_) {}
        expect(invalidated, entry.$5 ? ['fixture-old'] : isEmpty);
      });
    }
  }
  test(
    'rejection clears only its captured token; a replacement remains signed in',
    () async {
      final old = _session('old');
      final store = MemoryAuthSessionStore();
      await store.write(old);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_Repo(old)),
          authSessionStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      final controller = container.read(authControllerProvider.notifier);
      final next = _session('replacement');
      await store.write(next);
      controller.acceptNativeSession(next);
      await controller.expireSession(old.token);
      expect((await store.read())?.token, next.token);
      expect(container.read(authControllerProvider).value?.token, next.token);
      await controller.expireSession(next.token);
      expect(await store.read(), isNull);
      expect(container.read(authControllerProvider).value, isNull);
    },
  );
  testWidgets(
    'session expiration updates mounted screens without another request',
    (tester) async {
      final session = _session('expires', seconds: 1);
      final store = MemoryAuthSessionStore();
      await store.write(session);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_Repo(session)),
          authSessionStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      await container.read(authControllerProvider.future);
      await tester.pump(const Duration(seconds: 2));
      expect(container.read(authControllerProvider).value, isNull);
      expect(await store.read(), isNull);
    },
  );
}
