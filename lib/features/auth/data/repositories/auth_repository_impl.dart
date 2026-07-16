import 'dart:convert';
import 'dart:math';

import 'package:kidia_store_app/features/auth/data/network/auth_api_transport.dart';
import 'package:kidia_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:kidia_store_app/features/auth/data/storage/social_auth_pending_store.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_identity.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:kidia_store_app/features/auth/domain/entities/social_auth.dart';
import 'package:kidia_store_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl({
    required this.transport,
    required this.sessionStore,
    required this.socialPendingStore,
  });

  final AuthApiTransport transport;
  final AuthSessionStore sessionStore;
  final SocialAuthPendingStore socialPendingStore;

  @override
  Future<AuthIdentity> identify(String email) {
    return _guard(() => transport.identify(email));
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final AuthSession session = await _guard(
      () => transport.signIn(email: email, password: password),
    );
    await sessionStore.write(session);
    return session;
  }

  @override
  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    final AuthSession session = await _guard(
      () => transport.register(email: email, password: password),
    );
    await sessionStore.write(session);
    return session;
  }

  @override
  Future<Uri> beginSocialSignIn({
    required SocialAuthProvider provider,
    required String returnPath,
  }) async {
    if (!SocialAuthPending.isAllowedReturnPath(returnPath)) {
      throw const AuthRepositoryException(
        kind: AuthFailureKind.configuration,
        message: 'The social sign-in return screen is not approved.',
      );
    }
    final String state = _secureSecret(32);
    final String verifier = _secureSecret(48);
    final Uri authorizeUri = await _guard(
      () => transport.beginSocialSignIn(
        provider: provider,
        state: state,
        verifier: verifier,
      ),
    );
    await socialPendingStore.write(
      SocialAuthPending(
        state: state,
        verifier: verifier,
        returnPath: returnPath,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return authorizeUri;
  }

  @override
  Future<SocialAuthCompletion> completeSocialSignIn({
    required String code,
    required String state,
  }) async {
    final SocialAuthPending? pending = await socialPendingStore.read();
    if (pending == null || pending.isExpired) {
      await socialPendingStore.clear();
      throw const AuthRepositoryException(
        kind: AuthFailureKind.invalidInput,
        message: 'The social sign-in request is missing or expired.',
      );
    }
    if (!_constantTimeEquals(pending.state, state.trim())) {
      throw const AuthRepositoryException(
        kind: AuthFailureKind.invalidInput,
        message: 'The social sign-in request does not match this device.',
      );
    }
    final AuthSession session = await _guard(
      () => transport.exchangeSocialSignIn(
        code: code.trim(),
        state: pending.state,
        verifier: pending.verifier,
      ),
    );
    await sessionStore.write(session);
    await socialPendingStore.clear();
    return SocialAuthCompletion(
      session: session,
      returnPath: pending.returnPath,
    );
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final AuthSession? stored = await sessionStore.read();
    if (stored == null) {
      return null;
    }
    if (stored.isExpired) {
      await sessionStore.clear();
      return null;
    }

    try {
      final AuthUser user = await transport.currentUser(stored.token);
      final AuthSession refreshed = stored.copyWith(user: user);
      await sessionStore.write(refreshed);
      return refreshed;
    } on AuthApiException catch (error) {
      if (error.kind == AuthFailureKind.unauthorized ||
          error.kind == AuthFailureKind.invalidInput) {
        await sessionStore.clear();
        return null;
      }
      // An unexpired, locally secured session remains useful while offline.
      // Every protected server request still validates the bearer token.
      return stored;
    } on FormatException {
      await sessionStore.clear();
      return null;
    }
  }

  @override
  Future<void> signOut(AuthSession session) async {
    try {
      await transport.signOut(session.token);
    } finally {
      await sessionStore.clear();
    }
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on AuthRepositoryException {
      rethrow;
    } on AuthApiException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AuthRepositoryException(
          kind: error.kind,
          message: error.message,
          statusCode: error.statusCode,
          code: error.code,
          cause: error,
        ),
        stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AuthRepositoryException(
          kind: AuthFailureKind.invalidResponse,
          message: 'The store returned invalid authentication data.',
          cause: error,
        ),
        stackTrace,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        AuthRepositoryException(
          kind: AuthFailureKind.unknown,
          message: 'Customer authentication failed unexpectedly.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  static String _secureSecret(int byteLength) {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(
      byteLength,
      (_) => random.nextInt(256),
      growable: false,
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) {
      return false;
    }
    int difference = 0;
    for (int index = 0; index < left.length; index += 1) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }
}
