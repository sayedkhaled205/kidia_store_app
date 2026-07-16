import 'auth_session.dart';

enum SocialAuthProvider {
  google,
  facebook;

  String get apiName => name;
}

class SocialAuthPending {
  const SocialAuthPending({
    required this.state,
    required this.verifier,
    required this.returnPath,
    required this.createdAt,
  });

  factory SocialAuthPending.fromJson(Map<String, dynamic> json) {
    final String state = json['state']?.toString().trim() ?? '';
    final String verifier = json['verifier']?.toString().trim() ?? '';
    final String returnPath = json['return_path']?.toString().trim() ?? '';
    final DateTime? createdAt = DateTime.tryParse(
      json['created_at']?.toString().trim() ?? '',
    );
    if (!_isSafeSecret(state) ||
        !_isSafeSecret(verifier) ||
        !_isAllowedReturnPath(returnPath) ||
        createdAt == null) {
      throw const FormatException('The pending social sign-in is invalid.');
    }
    return SocialAuthPending(
      state: state,
      verifier: verifier,
      returnPath: returnPath,
      createdAt: createdAt.toUtc(),
    );
  }

  final String state;
  final String verifier;
  final String returnPath;
  final DateTime createdAt;

  bool get isExpired => createdAt
      .add(const Duration(minutes: 10))
      .isBefore(DateTime.now().toUtc());

  Map<String, dynamic> toJson() => <String, dynamic>{
    'state': state,
    'verifier': verifier,
    'return_path': returnPath,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  static bool isAllowedReturnPath(String path) => _isAllowedReturnPath(path);

  static bool _isAllowedReturnPath(String path) {
    return path == '/account' || path == '/checkout';
  }

  static bool _isSafeSecret(String value) {
    return value.length >= 43 &&
        value.length <= 128 &&
        RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);
  }
}

class SocialAuthCompletion {
  const SocialAuthCompletion({
    required this.session,
    required this.returnPath,
  });

  final AuthSession session;
  final String returnPath;
}
