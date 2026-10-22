import 'auth_session.dart';

class NativeAuthConfig {
  const NativeAuthConfig({
    this.enabled = true,
    this.methods = const {},
    this.firebase = const {},
    this.google = const {},
  });
  final bool enabled;
  final Map<String, bool> methods;
  final Map<String, dynamic> firebase;
  final Map<String, dynamic> google;
  bool allows(String method) => enabled && methods[method] == true;
  bool get supportsPhone => allows('phone_password') || allows('phone_otp');
  factory NativeAuthConfig.fromJson(Map<String, dynamic> json) =>
      NativeAuthConfig(
        enabled: json['enabled'] == true,
        methods: json['methods'] is Map
            ? Map<String, dynamic>.from(
                json['methods'] as Map,
              ).map((k, v) => MapEntry(k, v == true))
            : const {},
        firebase: json['firebase'] is Map
            ? Map<String, dynamic>.from(json['firebase'] as Map)
            : const {},
        google: json['google'] is Map
            ? Map<String, dynamic>.from(json['google'] as Map)
            : const {},
      );
}

class NativeAuthIdentity {
  const NativeAuthIdentity({
    required this.identifier,
    required this.kind,
    required this.methods,
  });
  final String identifier;
  final String kind;
  final List<String> methods;
  bool allows(String method) => methods.contains(method);
  factory NativeAuthIdentity.fromJson(Map<String, dynamic> json) {
    final identifier = json['identifier']?.toString() ?? '';
    final kind = json['kind']?.toString() ?? '';
    if (identifier.isEmpty ||
        !['email', 'phone'].contains(kind) ||
        json['methods'] is! List) {
      throw const FormatException('Invalid native sign-in identity.');
    }
    return NativeAuthIdentity(
      identifier: identifier,
      kind: kind,
      methods: List<String>.from(json['methods'] as List),
    );
  }
}

class NativeAuthAccount {
  const NativeAuthAccount({
    required this.id,
    required this.name,
    this.emailHint = '',
  });
  final int id;
  final String name;
  final String emailHint;
}

enum NativeAuthStatus { authenticated, selectAccount, registrationRequired }

class NativeAuthResult {
  const NativeAuthResult({
    required this.status,
    this.session,
    this.ticket = '',
    this.accounts = const [],
    this.fields = const [],
    this.expiresIn = 0,
  });
  final NativeAuthStatus status;
  final AuthSession? session;
  final String ticket;
  final List<NativeAuthAccount> accounts;
  final List<String> fields;
  final int expiresIn;
  factory NativeAuthResult.fromJson(Map<String, dynamic> json) {
    if (json['status'] == 'authenticated') {
      final session = AuthSession.fromJson(json);
      if (session.isExpired ||
          session.token.contains(RegExp(r'[\x00-\x20\x7f]'))) {
        throw const FormatException('Invalid native session.');
      }
      return NativeAuthResult(
        status: NativeAuthStatus.authenticated,
        session: session,
      );
    }
    final ticket = json['ticket']?.toString() ?? '';
    final ttl = int.tryParse('${json['expires_in']}') ?? 0;
    if (ticket.isEmpty || ticket.length > 512 || ttl <= 0 || ttl > 900) {
      throw const FormatException('Invalid native sign-in continuation.');
    }
    if (json['status'] == 'select_account' && json['accounts'] is List) {
      final accounts = (json['accounts'] as List)
          .map((item) {
            if (item is! Map)
              throw const FormatException('Invalid account choice.');
            final id = int.tryParse('${item['id']}') ?? 0;
            final name = item['name']?.toString() ?? '';
            if (id <= 0 || name.isEmpty)
              throw const FormatException('Invalid account choice.');
            return NativeAuthAccount(
              id: id,
              name: name,
              emailHint: item['email_hint']?.toString() ?? '',
            );
          })
          .toList(growable: false);
      if (accounts.isEmpty ||
          accounts.map((a) => a.id).toSet().length != accounts.length) {
        throw const FormatException('Invalid account choices.');
      }
      return NativeAuthResult(
        status: NativeAuthStatus.selectAccount,
        ticket: ticket,
        expiresIn: ttl,
        accounts: accounts,
      );
    }
    if (json['status'] == 'registration_required' && json['fields'] is List) {
      final fields = List<String>.from(json['fields'] as List);
      if (fields.any(
        (f) => !['name', 'password', 'email', 'phone'].contains(f),
      )) {
        throw const FormatException('Unsupported sign-in completion fields.');
      }
      return NativeAuthResult(
        status: NativeAuthStatus.registrationRequired,
        ticket: ticket,
        expiresIn: ttl,
        fields: fields,
      );
    }
    throw const FormatException('Unsupported native sign-in result.');
  }
}

class NativeOtpChallenge {
  const NativeOtpChallenge({
    required this.phone,
    required this.handle,
    required this.automaticResult,
    this.resendToken,
  });
  final String phone;
  final Object handle;
  final int? resendToken;
  final Future<NativeAuthResult?> automaticResult;
}

abstract interface class NativeAuthActions {
  Future<NativeAuthConfig> config();
  Future<NativeAuthIdentity> identify(String identifier);
  Future<NativeAuthResult> password(String identifier, String password);
  Future<NativeOtpChallenge> sendOtp(
    String phone, {
    NativeOtpChallenge? resend,
    String? ticket,
  });
  Future<NativeAuthResult> verifyOtp(
    NativeOtpChallenge challenge,
    String code, {
    String? ticket,
  });
  Future<NativeAuthResult> google();
  Future<NativeAuthResult> selectAccount(String ticket, int accountId);
  Future<NativeAuthResult> register(
    String ticket, {
    required String name,
    required String password,
    String? email,
  });
  Future<AuthSession> commit(NativeAuthResult result);
  Future<void> cancel();
}
