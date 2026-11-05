import 'package:google_sign_in/google_sign_in.dart';
// The public Flutter API only offers previously authorized accounts first.
// Keep the locked Android host adapter isolated to this explicit button flow.
// ignore: implementation_imports
import 'package:google_sign_in_android/src/messages.g.dart';

Future<String?> pickAndroidGoogleAccount(
  String serverClientId, {
  GoogleSignInApi? host,
}) async {
  final result = await (host ?? GoogleSignInApi()).getCredential(
    GetCredentialRequestParams(
      useButtonFlow: false,
      serverClientId: serverClientId,
      googleIdOptionParams: GetCredentialRequestGoogleIdOptionParams(
        filterToAuthorized: false,
        autoSelectEnabled: false,
      ),
    ),
  );
  switch (result) {
    case GetCredentialSuccess():
      return result.credential.idToken;
    case GetCredentialFailure():
      if (result.type == GetCredentialFailureType.noCredential ||
          result.type == GetCredentialFailureType.noActivity) {
        return null;
      }
      final code = switch (result.type) {
        GetCredentialFailureType.canceled => GoogleSignInExceptionCode.canceled,
        GetCredentialFailureType.interrupted =>
          GoogleSignInExceptionCode.interrupted,
        GetCredentialFailureType.missingServerClientId =>
          GoogleSignInExceptionCode.clientConfigurationError,
        GetCredentialFailureType.unknown =>
          GoogleSignInExceptionCode.unknownError,
        _ => GoogleSignInExceptionCode.providerConfigurationError,
      };
      throw GoogleSignInException(code: code);
  }
}
