import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/analytics/mobile_analytics.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_identity.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/social_auth.dart';
import 'package:mobishop_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';

class AuthController extends AsyncNotifier<AuthSession?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AuthSession?> build() => _repository.restoreSession();

  Future<AuthIdentity> identify(String email) {
    return _repository.identify(email.trim());
  }

  /// Apply the profile confirmed by the store without restarting authentication.
  /// The next session restore reads the authoritative user from the store again;
  /// the session token and its expiry must never change for a profile edit.
  void updateUserFromServer(AuthUser user) {
    if (!ref.mounted) return;
    final AuthSession? session = state.value;
    if (session == null || session.isExpired || session.user.id != user.id) {
      return;
    }
    state = AsyncData<AuthSession?>(session.copyWith(user: user));
  }

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final Ref operationRef = ref;
    final AuthSession session = await _repository.signIn(
      email: email.trim(),
      password: password,
    );
    if (!operationRef.mounted) return session;
    state = AsyncData<AuthSession?>(session);
    ref
        .read(mobileAnalyticsProvider)
        .trackInBackground('login', authToken: session.token);
    return session;
  }

  Future<AuthSession> register({
    required String email,
    required String password,
  }) async {
    final Ref operationRef = ref;
    ref.read(mobileAnalyticsProvider).trackInBackground('registration_started');
    final AuthSession session = await _repository.register(
      email: email.trim(),
      password: password,
    );
    if (!operationRef.mounted) return session;
    state = AsyncData<AuthSession?>(session);
    ref
        .read(mobileAnalyticsProvider)
        .trackInBackground('sign_up', authToken: session.token);
    return session;
  }

  Future<Uri> beginSocialSignIn({
    required SocialAuthProvider provider,
    required String returnPath,
  }) {
    return _repository.beginSocialSignIn(
      provider: provider,
      returnPath: returnPath,
    );
  }

  Future<SocialAuthCompletion> completeSocialSignIn({
    required String code,
    required String callbackState,
  }) async {
    final Ref operationRef = ref;
    final SocialAuthCompletion completion = await _repository
        .completeSocialSignIn(code: code, state: callbackState);
    if (!operationRef.mounted) return completion;
    state = AsyncData<AuthSession?>(completion.session);
    ref
        .read(mobileAnalyticsProvider)
        .trackInBackground('login', authToken: completion.session.token);
    return completion;
  }

  Future<void> signOut() async {
    final Ref operationRef = ref;
    final AuthSession? session = state.value;
    if (session == null) {
      if (ref.mounted) state = const AsyncData<AuthSession?>(null);
      return;
    }
    try {
      await _repository.signOut(session);
    } finally {
      if (operationRef.mounted) state = const AsyncData<AuthSession?>(null);
    }
  }
}
