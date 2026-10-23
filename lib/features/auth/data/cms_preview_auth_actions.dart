import '../domain/entities/auth_session.dart';
import '../domain/entities/native_auth.dart';
import '../domain/repositories/auth_repository.dart';

/// The editor displays the connected store's methods without issuing identity
/// proofs, sending SMS, or creating customer sessions inside the builder.
class CmsPreviewAuthActions implements NativeAuthActions {
  CmsPreviewAuthActions(this.loadConfiguration, {required this.isArabic});

  final Future<Map<String, dynamic>> Function() loadConfiguration;
  final bool isArabic;

  @override
  Future<NativeAuthConfig> config() async {
    final json = await loadConfiguration();
    if (json['error'] != null ||
        json['version'] != 1 ||
        json['enabled'] is! bool ||
        json['methods'] is! Map) {
      throw const FormatException(
        'Preview authentication settings unavailable.',
      );
    }
    // Only public availability flags belong in the visual preview.
    return NativeAuthConfig.fromJson({
      'enabled': json['enabled'],
      'methods': json['methods'],
    });
  }

  Future<T> _previewOnly<T>() => Future<T>.error(
    AuthRepositoryException(
      kind: AuthFailureKind.configuration,
      code: 'preview-only',
      message: isArabic
          ? 'دي معاينة لشاشة الدخول. جرّب تسجيل الدخول من تطبيق الموبايل.'
          : 'This is a sign-in preview. Try signing in from the mobile app.',
    ),
  );

  @override
  Future<NativeAuthIdentity> identify(String identifier) => _previewOnly();
  @override
  Future<NativeAuthResult> password(String identifier, String password) =>
      _previewOnly();
  @override
  Future<NativeOtpChallenge> sendOtp(
    String phone, {
    NativeOtpChallenge? resend,
    String? ticket,
  }) => _previewOnly();
  @override
  Future<NativeAuthResult> verifyOtp(
    NativeOtpChallenge challenge,
    String code, {
    String? ticket,
  }) => _previewOnly();
  @override
  Future<NativeAuthResult> google() => _previewOnly();
  @override
  Future<NativeAuthResult> selectAccount(String ticket, int accountId) =>
      _previewOnly();
  @override
  Future<NativeAuthResult> register(
    String ticket, {
    required String name,
    required String password,
    String? email,
  }) => _previewOnly();
  @override
  Future<AuthSession> commit(NativeAuthResult result) => _previewOnly();
  @override
  Future<void> cancel() async {}
}
