import 'auth_user.dart';

class AuthSession {
  const AuthSession({
    required this.token,
    required this.expiresAt,
    required this.user,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final String token = json['token']?.toString().trim() ?? '';
    final DateTime? expiresAt = DateTime.tryParse(
      json['expires_at']?.toString().trim() ?? '',
    );
    final dynamic rawUser = json['user'];
    if (token.isEmpty ||
        token.length > 512 ||
        expiresAt == null ||
        rawUser is! Map) {
      throw const FormatException('The authentication session is invalid.');
    }

    return AuthSession(
      token: token,
      expiresAt: expiresAt.toUtc(),
      user: AuthUser.fromJson(Map<String, dynamic>.from(rawUser)),
    );
  }

  final String token;
  final DateTime expiresAt;
  final AuthUser user;

  bool get isExpired => !expiresAt.isAfter(DateTime.now().toUtc());

  AuthSession copyWith({AuthUser? user}) {
    return AuthSession(
      token: token,
      expiresAt: expiresAt,
      user: user ?? this.user,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'token': token,
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'user': user.toJson(),
  };
}
