// Verify the locked platform adapter, not just an app-level fake: a first-time
// customer must be offered eligible accounts even without prior authorization.
// ignore_for_file: depend_on_referenced_packages, implementation_imports
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_android/google_sign_in_android.dart';
import 'package:google_sign_in_android/src/messages.g.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

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
    'fresh Android install tries all eligible accounts in the sheet',
    () async {
      final host = _Credentials();
      final android = GoogleSignInAndroid(api: host);
      await android.init(
        const InitParameters(
          serverClientId: 'fixture.apps.googleusercontent.com',
        ),
      );
      final result = await android.attemptLightweightAuthentication(
        const AttemptLightweightAuthenticationParameters(),
      );
      expect(result?.user.email, 'fixture@example.com');
      expect(host.requests, hasLength(2));
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
