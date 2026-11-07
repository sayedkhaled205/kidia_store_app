import '../../auth/data/native_auth_sdk.dart';
import '../data/network/customer_account_api_transport.dart';

class AppleDeletionRequiresIos implements Exception {
  const AppleDeletionRequiresIos();
}

/// The caller persists the receipt before entering this flow. No step is retried
/// automatically: after an ambiguous result, use the saved server receipt.
Future<Map<String, dynamic>> requestAccountIdentityDeletion({
  required CustomerAccountIdentityDeletionTransport transport,
  required String receipt,
  required String expectedSession,
  required int userId,
  required NativeAppleDeletionSdk appleSdk,
  required Future<Map<String, dynamic>> Function() loadAppleConfig,
  required bool isApplePlatform,
  required bool Function() isCurrentAccount,
}) async {
  void checkCurrent() {
    if (!isCurrentAccount()) {
      throw StateError('The account changed during deletion confirmation');
    }
  }

  checkCurrent();
  final prepared = await transport.prepareIdentityDeletion(
    receipt: receipt,
    expectedSession: expectedSession,
  );
  checkCurrent();
  if (prepared['status'] != 'prepared' ||
      prepared['user_id'] is! int ||
      prepared['user_id'] != userId ||
      prepared['apple_revocation_required'] is! bool) {
    throw const FormatException('Invalid deletion preparation response');
  }
  var appleRevoked = false;
  if (prepared['apple_revocation_required'] == true) {
    if (!isApplePlatform) throw const AppleDeletionRequiresIos();
    final config = await loadAppleConfig();
    checkCurrent();
    var proofApproved = false;
    await appleSdk.deleteAppleIdentity(
      config,
      isCurrentAccount: isCurrentAccount,
      validateIdentity: (idToken) async {
        checkCurrent();
        final response = await transport.validateAppleDeletion(
          receipt: receipt,
          expectedSession: expectedSession,
          idToken: idToken,
        );
        checkCurrent();
        proofApproved = response['approved'] == true;
        return proofApproved;
      },
    );
    checkCurrent();
    if (!proofApproved) {
      throw StateError('Apple deletion proof was not approved');
    }
    appleRevoked = true;
  }
  checkCurrent();
  final result = await transport.finalizeIdentityDeletion(
    receipt: receipt,
    expectedSession: expectedSession,
    appleRevoked: appleRevoked,
  );
  checkCurrent();
  if (result['status'] != 'pending' ||
      result['user_id'] is! int ||
      result['user_id'] != userId) {
    throw const FormatException('Invalid deletion response');
  }
  return result;
}
