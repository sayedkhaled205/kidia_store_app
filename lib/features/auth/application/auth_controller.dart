import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/analytics/mobile_analytics.dart';
import 'package:mobishop_store_app/features/auth/data/website_auth_service.dart';
import '../data/storage/auth_session_store.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_identity.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/social_auth.dart';
import 'package:mobishop_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/website_auth_providers.dart';

class AuthController extends AsyncNotifier<AuthSession?> {
  Future<void>? _signOutOperation;
  String? _signOutToken;
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  /// The deletion endpoint already revoked the captured server session.
  Future<void> completeAccountDeletion(String token) async {
    final store = ref.read(authSessionStoreProvider);
    if (store is! ConditionalAuthSessionStore) {
      throw StateError('Conditional session cleanup is unavailable.');
    }
    await (store as ConditionalAuthSessionStore).clearIfToken(token);
    if (ref.mounted && state.value?.token == token) {
      state = const AsyncData<AuthSession?>(null);
    }
  }

  @override
  Future<AuthSession?> build() => _repository.restoreSession();

  Future<AuthIdentity> identify(String email) {
    return _repository.identify(email.trim());
  }

  /// Called only after the native proof service securely commits its session.
  void acceptNativeSession(AuthSession session) {
    if (!ref.mounted || session.isExpired) return;
    state = AsyncData<AuthSession?>(session);
    ref
        .read(mobileAnalyticsProvider)
        .trackInBackground('login', authToken: session.token);
  }

  Future<AuthSession> signInThroughWebsite({
    String? provider,
    WebsiteAuthBrowser? presenter,
    WebsiteAuthAttempt? attempt,
  }) async {
    final operationRef = ref;
    final session = await ref
        .read(websiteAuthServiceProvider)
        .signIn(provider: provider, presenter: presenter, attempt: attempt);
    attempt?.checkActive();
    if (!operationRef.mounted) return session;
    state = AsyncData<AuthSession?>(session);
    ref
        .read(mobileAnalyticsProvider)
        .trackInBackground('login', authToken: session.token);
    return session;
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

  Future<void> signOut() {
    final token = state.value?.token;
    if (_signOutOperation != null && _signOutToken == token) {
      return _signOutOperation!;
    }
    _signOutToken = token;
    late final Future<void> operation;
    operation = _performSignOut().whenComplete(() {
      if (identical(_signOutOperation, operation)) {
        _signOutOperation = null;
        _signOutToken = null;
      }
    });
    return _signOutOperation = operation;
  }

  Future<void> _performSignOut() async {
    final Ref operationRef = ref;
    final AuthSession? session = state.value;
    if (session == null) {
      if (ref.mounted) state = const AsyncData<AuthSession?>(null);
      return;
    }
    bool localSessionCleared = true;
    try {
      await _repository.signOut(session);
    } on AuthRepositoryException catch (error) {
      localSessionCleared = error.code != 'local_sign_out_failed';
      rethrow;
    } finally {
      if (operationRef.mounted &&
          localSessionCleared &&
          state.value?.token == session.token) {
        state = const AsyncData<AuthSession?>(null);
      }
    }
  }
}
