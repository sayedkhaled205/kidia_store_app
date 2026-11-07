import '../../auth/data/native_auth_sdk.dart';
import '../data/network/customer_account_api_transport.dart';
import '../data/storage/account_deletion_receipt_store.dart';

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
  required Future<void> Function(AppleDeletionCheckpoint)
  persistAppleCheckpoint,
  AppleDeletionCheckpoint? appleCheckpoint,
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
      prepared['apple_revocation_required'] is! bool ||
      !AppleDeletionCheckpoint.isDigest(prepared['intent_id'])) {
    throw const FormatException('Invalid deletion preparation response');
  }
  final intentId = prepared['intent_id'] as String;
  if (appleCheckpoint != null &&
      (!appleCheckpoint.isValid ||
          appleCheckpoint.receipt != receipt ||
          appleCheckpoint.userId != userId ||
          appleCheckpoint.intentId != intentId ||
          prepared['apple_revocation_required'] != true)) {
    throw StateError('The completed Apple operation belongs to another intent');
  }
  var appleRevoked = false;
  if (prepared['apple_revocation_required'] == true) {
    if (appleCheckpoint == null) {
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
      if (!proofApproved) {
        throw StateError('Apple deletion proof was not approved');
      }
    }
    // Record known SDK success even if the session changed on its return;
    // persistence is bound to the captured receipt, not the new account.
    // A successful authenticated prepare confirms the immutable intent even
    // after same-owner reauthentication. Persist/rebind before finalizing; an
    // explicit retry then never opens Apple or creates a replacement identity.
    await persistAppleCheckpoint(
      AppleDeletionCheckpoint(
        receipt: receipt,
        userId: userId,
        sessionHash: AccountDeletionReceipt.hashSession(expectedSession),
        intentId: intentId,
      ),
    );
    checkCurrent();
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
