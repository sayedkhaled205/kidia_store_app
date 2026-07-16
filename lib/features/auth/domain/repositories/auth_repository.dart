import '../entities/auth_identity.dart';
import '../entities/auth_session.dart';

enum AuthFailureKind {
  configuration,
  invalidInput,
  unauthorized,
  conflict,
  rateLimited,
  timeout,
  connection,
  certificate,
  server,
  invalidResponse,
  unknown,
}

class AuthRepositoryException implements Exception {
  const AuthRepositoryException({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.cause,
  });

  final AuthFailureKind kind;
  final String message;
  final int? statusCode;
  final String? code;
  final Object? cause;

  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  Future<AuthIdentity> identify(String email);

  Future<AuthSession> signIn({
    required String email,
    required String password,
  });

  Future<AuthSession> register({
    required String email,
    required String password,
  });

  Future<AuthSession?> restoreSession();

  Future<void> signOut(AuthSession session);
}
