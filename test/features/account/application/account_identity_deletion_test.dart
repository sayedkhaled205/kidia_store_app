import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/account/application/account_identity_deletion.dart';
import 'package:mobishop_store_app/features/account/data/network/customer_account_api_transport.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_sdk.dart';

void main() {
  late _Transport transport;
  late _Apple sdk;
  late List<String> calls;
  var current = true;
  var applePlatform = true;
  Future<Map<String, dynamic>> run() => requestAccountIdentityDeletion(
    transport: transport,
    receipt: 'persisted-receipt',
    expectedSession: 'captured-session',
    userId: 7,
    appleSdk: sdk,
    loadAppleConfig: () async {
      calls.add('config');
      return {'projectId': 'synthetic-project'};
    },
    isApplePlatform: applePlatform,
    isCurrentAccount: () => current,
  );
  setUp(() {
    calls = [];
    transport = _Transport(calls);
    sdk = _Apple(calls);
    current = true;
    applePlatform = true;
  });
  test(
    'non-Apple account finalizes without native configuration or SDK',
    () async {
      transport.prepared['apple_revocation_required'] = false;
      applePlatform = false;
      expect(await run(), {'status': 'pending', 'user_id': 7});
      expect(calls, ['prepare', 'finalize:false']);
    },
  );
  test(
    'Apple proof must be approved before revocation and final confirmation',
    () async {
      expect(await run(), {'status': 'pending', 'user_id': 7});
      expect(calls, [
        'prepare',
        'config',
        'apple',
        'proof',
        'revoke',
        'delete-identity',
        'finalize:true',
      ]);
    },
  );
  test('Android never opens Apple or finalizes a linked identity', () async {
    applePlatform = false;
    await expectLater(run(), throwsA(isA<AppleDeletionRequiresIos>()));
    expect(calls, ['prepare']);
  });
  for (final bad in [
    {'status': 'pending', 'user_id': 7, 'apple_revocation_required': true},
    {'status': 'prepared', 'user_id': 8, 'apple_revocation_required': true},
    {'status': 'prepared', 'user_id': '7', 'apple_revocation_required': true},
    {'status': 'prepared', 'user_id': 7},
    {'status': 'prepared', 'user_id': 7, 'apple_revocation_required': 'false'},
  ]) {
    test('unconfirmed preparation cannot start Apple: $bad', () async {
      transport.prepared = bad;
      await expectLater(run(), throwsFormatException);
      expect(calls, ['prepare']);
    });
  }
  for (final approval in [false, null, 'true']) {
    test(
      'non-true proof approval prevents destructive steps: $approval',
      () async {
        transport.approval = approval;
        await expectLater(run(), throwsA(isA<NativeAuthSdkException>()));
        expect(calls, ['prepare', 'config', 'apple', 'proof']);
      },
    );
  }
  test('SDK cannot omit proof validation and still finalize', () async {
    sdk.skipProof = true;
    await expectLater(run(), throwsStateError);
    expect(calls, ['prepare', 'config', 'apple']);
  });
  for (final step in ['prepare', 'proof', 'finalize']) {
    test('an unavailable $step is not automatically retried', () async {
      transport.failure = step;
      await expectLater(
        run(),
        throwsA(isA<CustomerAccountTransportException>()),
      );
      expect(calls.where((e) => e == step || e.startsWith('$step:')).length, 1);
      if (step != 'finalize') {
        expect(calls.where((e) => e.startsWith('finalize')), isEmpty);
      }
    });
  }
  for (final step in ['apple', 'revoke', 'delete-identity']) {
    test(
      'SDK cancellation or ambiguous $step failure cannot finalize',
      () async {
        sdk.failure = step;
        await expectLater(run(), throwsA(isA<NativeAuthSdkException>()));
        expect(calls.where((e) => e.startsWith('finalize')), isEmpty);
      },
    );
  }
  test('stale captured account cannot prepare', () async {
    current = false;
    await expectLater(run(), throwsStateError);
    expect(calls, isEmpty);
  });
  for (final step in ['prepare', 'proof', 'delete-identity']) {
    test('account/store/session change after $step cannot finalize', () async {
      transport.afterStep = (s) {
        if (s == step) current = false;
      };
      sdk.afterStep = (s) {
        if (s == step) current = false;
      };
      await expectLater(run(), throwsStateError);
      expect(calls.where((e) => e.startsWith('finalize')), isEmpty);
    });
  }
  test(
    'SDK receives current-account guard while provider is pending',
    () async {
      final gate = Completer<void>();
      sdk.gate = gate.future;
      final result = run();
      await Future<void>.delayed(Duration.zero);
      current = false;
      gate.complete();
      await expectLater(result, throwsStateError);
      expect(calls, ['prepare', 'config', 'apple']);
    },
  );
  test(
    'a late account change rejects final result for receipt recovery',
    () async {
      transport.afterStep = (s) {
        if (s == 'finalize') current = false;
      };
      await expectLater(run(), throwsStateError);
      expect(calls.last, 'finalize:true');
    },
  );
  for (final result in [
    {'status': 'completed', 'user_id': 7},
    {'status': 'pending', 'user_id': 8},
  ]) {
    test(
      'invalid final response is ambiguous and not accepted: $result',
      () async {
        transport.result = result;
        await expectLater(run(), throwsFormatException);
        expect(calls.last, 'finalize:true');
      },
    );
  }
}

class _Transport implements CustomerAccountIdentityDeletionTransport {
  _Transport(this.calls);
  final List<String> calls;
  Map<String, dynamic> prepared = {
    'status': 'prepared',
    'user_id': 7,
    'apple_revocation_required': true,
  };
  Map<String, dynamic> result = {'status': 'pending', 'user_id': 7};
  Object? approval = true;
  String? failure;
  void Function(String)? afterStep;
  void step(String value, String receipt, String session) {
    expect(receipt, 'persisted-receipt');
    expect(session, 'captured-session');
    calls.add(value);
    if (failure == value.split(':').first) {
      throw const CustomerAccountTransportException(
        kind: CustomerAccountTransportFailureKind.connection,
        message: 'Synthetic outage',
      );
    }
    afterStep?.call(value.split(':').first);
  }

  @override
  Future<Map<String, dynamic>> prepareIdentityDeletion({
    required String receipt,
    required String expectedSession,
  }) async {
    step('prepare', receipt, expectedSession);
    return prepared;
  }

  @override
  Future<Map<String, dynamic>> validateAppleDeletion({
    required String receipt,
    required String expectedSession,
    required String idToken,
  }) async {
    expect(idToken, 'fresh-fixture-proof');
    step('proof', receipt, expectedSession);
    return {'approved': approval};
  }

  @override
  Future<Map<String, dynamic>> finalizeIdentityDeletion({
    required String receipt,
    required String expectedSession,
    required bool appleRevoked,
  }) async {
    step('finalize:$appleRevoked', receipt, expectedSession);
    return result;
  }
}

class _Apple implements NativeAppleDeletionSdk {
  _Apple(this.calls);
  final List<String> calls;
  bool skipProof = false;
  String? failure;
  Future<void>? gate;
  void Function(String)? afterStep;
  void step(String value) {
    calls.add(value);
    if (failure == value) throw const NativeAuthSdkException('cancelled');
    afterStep?.call(value);
  }

  @override
  Future<void> deleteAppleIdentity(
    Map<String, dynamic> config, {
    required Future<bool> Function(String) validateIdentity,
    required bool Function() isCurrentAccount,
  }) async {
    expect(config['projectId'], 'synthetic-project');
    step('apple');
    if (skipProof) return;
    if (gate != null) await gate;
    if (!isCurrentAccount()) {
      throw StateError('Synthetic current-account guard');
    }
    if (!await validateIdentity('fresh-fixture-proof')) {
      throw const NativeAuthSdkException('identity-rejected');
    }
    step('revoke');
    step('delete-identity');
  }
}
