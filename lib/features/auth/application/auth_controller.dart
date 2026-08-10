import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/analytics/mobile_analytics.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_identity.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
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

  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final AuthSession session = await _repository.signIn(
      email: email.trim(),
      password: password,
    );
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
    ref.read(mobileAnalyticsProvider).trackInBackground('registration_started');
    final AuthSession session = await _repository.register(
      email: email.trim(),
      password: password,
    );
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
    final SocialAuthCompletion completion = await _repository
        .completeSocialSignIn(code: code, state: callbackState);
    state = AsyncData<AuthSession?>(completion.session);
    ref
        .read(mobileAnalyticsProvider)
        .trackInBackground('login', authToken: completion.session.token);
    return completion;
  }

  Future<void> signOut() async {
    final AuthSession? session = state.asData?.value;
    if (session == null) {
      state = const AsyncData<AuthSession?>(null);
      return;
    }
    try {
      await _repository.signOut(session);
    } finally {
      state = const AsyncData<AuthSession?>(null);
    }
  }
}
