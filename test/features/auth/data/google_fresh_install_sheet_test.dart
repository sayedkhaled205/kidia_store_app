// Verify the locked platform adapter, not just an app-level fake: a first-time
// customer must be offered eligible accounts even without prior authorization.
// ignore_for_file: depend_on_referenced_packages, implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/auth/data/android_google_account_picker.dart';
import 'package:google_sign_in_android/src/messages.g.dart';

class _Credentials extends GoogleSignInApi {
  final requests = <GetCredentialRequestParams>[];
  @override
  Future<GetCredentialResult> getCredential(
    GetCredentialRequestParams params,
  ) async {
    requests.add(params);
    if (params.googleIdOptionParams.filterToAuthorized) {
      return GetCredentialFailure(type: GetCredentialFailureType.noCredential);
    }
    return GetCredentialSuccess(
      credential: PlatformGoogleIdTokenCredential(
        email: 'fixture@example.com',
        uniqueId: 'fixture',
        idToken: 'fixture-proof',
      ),
    );
  }
}

void main() {
  test(
    'Google button requests all eligible accounts on the first sheet',
    () async {
      final host = _Credentials();
      final token = await pickAndroidGoogleAccount(
        'fixture.apps.googleusercontent.com',
        host: host,
      );
      expect(token, 'fixture-proof');
      expect(host.requests, hasLength(1));
      expect(
        host.requests.single.serverClientId,
        'fixture.apps.googleusercontent.com',
      );
      expect(host.requests.every((r) => !r.useButtonFlow), isTrue);
      expect(
        host.requests.last.googleIdOptionParams.filterToAuthorized,
        isFalse,
      );
      expect(
        host.requests.last.googleIdOptionParams.autoSelectEnabled,
        isFalse,
      );
    },
  );
}
