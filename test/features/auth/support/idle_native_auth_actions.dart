import 'package:mobishop_store_app/features/auth/domain/entities/native_auth.dart';

/// Navigation fixtures show and dismiss native sign-in without network or SDKs.
class IdleNativeAuthActions implements NativeAuthActions {
  @override
  Future<NativeAuthConfig> config() async =>
      const NativeAuthConfig(methods: {'email_password': true});

  @override
  Future<void> cancel() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
