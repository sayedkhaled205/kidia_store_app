import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobishop_store_app/features/account/presentation/account_deletion_screen.dart';
import 'package:mobishop_store_app/features/account/data/network/customer_account_api_transport.dart';
import 'package:mobishop_store_app/features/account/data/storage/account_deletion_receipt_store.dart';
import 'package:mobishop_store_app/features/auth/application/auth_controller.dart';
import 'package:mobishop_store_app/features/auth/data/native_auth_sdk.dart';
import 'package:mobishop_store_app/features/auth/data/storage/auth_session_store.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/native_auth.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/native_auth_providers.dart';
import '../../auth/data/native_apple_deletion_sdk_test.dart'
    show DeletionBackend;

AuthSession _session(String token, {int id = 7}) => AuthSession(
  token: token,
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  user: AuthUser(id: id, email: 'synthetic@example.invalid'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AccountDeletionReceiptStore receipts;
  late MemoryAuthSessionStore sessions;
  late _Auth auth;
  late _Transport transport;
  late _Apple sdk;
  late List<String> calls;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    receipts = AccountDeletionReceiptStore('https://synthetic.example.invalid');
    sessions = MemoryAuthSessionStore()..value = _session('original');
    auth = _Auth(sessions.value!);
    calls = [];
    transport = _Transport(calls, receipts);
    sdk = _Apple(calls);
  });
  Future<void> open(
    WidgetTester tester, {
    bool statusOnly = false,
    CustomerAccountDeletionTransport? api,
    NativeAppleDeletionSdk? appleClient,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => auth),
          authSessionStoreProvider.overrideWithValue(sessions),
          accountDeletionReceiptStoreProvider.overrideWithValue(receipts),
          accountDeletionTransportProvider.overrideWithValue(api ?? transport),
          accountDeletionAppleSdkProvider.overrideWithValue(appleClient ?? sdk),
          nativeAuthConfigProvider.overrideWith((ref) async {
            calls.add('config');
            return const NativeAuthConfig(
              methods: {'apple': true},
              firebase: {
                'projectId': 'synthetic-project',
                'appId': '1:123:ios:fixture',
                'apiKey': 'public-fixture',
                'messagingSenderId': '123',
                'iosBundleId': 'app.fixture',
              },
            );
          }),
        ],
        child: MaterialApp(
          home: AccountDeletionScreen(userId: statusOnly ? null : 7),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester, {bool settle = true}) async {
    final checkbox = find.byKey(const Key('confirm-account-deletion'));
    await tester.ensureVisible(checkbox);
    await tester.tap(checkbox);
    await tester.pump();
    final button = find.byKey(const Key('request-account-deletion'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  deletionWidgetTest(
    'receipt is persisted before Apple and successful confirmation',
    (tester) async {
      await open(tester);
      expect(calls, isEmpty);
      await confirm(tester);
      expect(calls, [
        'prepare',
        'config',
        'apple',
        'proof',
        'revoked',
        'finalize:true',
      ]);
      expect(find.text('Account deletion requested'), findsOneWidget);
      expect(sessions.value, null);
      expect(await receipts.read(), isNotNull);
    },
  );
  deletionWidgetTest(
    'screen passes native configuration through the real Apple SDK',
    (tester) async {
      final backend = DeletionBackend()..token = 'fresh-fixture-proof';
      backend.onAuthenticate = () async {
        calls.add('apple');
      };
      backend.onRevoke = () async {
        calls.add('revoked');
      };
      backend.onDelete = () async {
        calls.add('identity-deleted');
      };
      backend.onSignOut = () async {
        calls.add('sign-out');
      };
      final realSdk = FirebaseNativeAuthSdk(
        platform: TargetPlatform.iOS,
        isWeb: false,
        appleBackendFactory: (options) async {
          expect(options['projectId'], 'synthetic-project');
          expect(options['appId'], '1:123:ios:fixture');
          return backend;
        },
      );
      await open(tester, appleClient: realSdk);
      await confirm(tester);
      expect(calls, [
        'prepare',
        'config',
        'apple',
        'proof',
        'revoked',
        'identity-deleted',
        'sign-out',
        'finalize:true',
      ]);
      expect(find.text('Account deletion requested'), findsOneWidget);
    },
  );
  deletionWidgetTest(
    'real Apple SDK preserves merchant reauthentication without deleting or signing out',
    (tester) async {
      transport.proofError = const CustomerAccountTransportException(
        kind: CustomerAccountTransportFailureKind.unauthorized,
        message: 'Private upstream details must not be displayed',
        code: 'mobishop_account_deletion_reauth',
        statusCode: 401,
      );
      final backend = DeletionBackend()..token = 'fresh-fixture-proof';
      final realSdk = FirebaseNativeAuthSdk(
        platform: TargetPlatform.iOS,
        isWeb: false,
        appleBackendFactory: (_) async => backend,
      );
      await open(tester, appleClient: realSdk);
      await confirm(tester);
      expect(calls, ['prepare', 'config', 'proof']);
      expect(backend.calls, ['authenticate', 'signOut']);
      expect(find.text('Sign in to confirm'), findsOneWidget);
      expect(find.textContaining('Private upstream'), findsNothing);
      expect(sessions.value?.token, 'original');
      expect(await receipts.read(), isNotNull);
      expect(find.text('Account deletion requested'), findsNothing);
    },
  );
  deletionWidgetTest(
    'Apple revocation failure is visible above actions on a small iPhone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 700);
      addTearDown(tester.view.reset);
      final backend = DeletionBackend()..token = 'fresh-fixture-proof';
      backend.onRevoke = () async =>
          throw StateError('private provider details');
      final realSdk = FirebaseNativeAuthSdk(
        platform: TargetPlatform.iOS,
        isWeb: false,
        appleBackendFactory: (_) async => backend,
      );
      await open(tester, appleClient: realSdk);
      await confirm(tester);
      expect(backend.calls, ['authenticate', 'revoke', 'signOut']);
      expect(calls, ['prepare', 'config', 'proof']);
      expect(
        find.textContaining('We could not confirm disconnecting Apple'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('account-deletion-error')).hitTestable(),
        findsOneWidget,
      );
      expect(find.textContaining('private provider'), findsNothing);
      expect(find.textContaining('Your request is saved'), findsNothing);
      expect(sessions.value?.token, 'original');
      expect(await receipts.read(), isNotNull);
    },
  );
  deletionWidgetTest(
    'late Apple cancellation never claims identity removal did not occur',
    (tester) async {
      final backend = DeletionBackend()..token = 'fresh-fixture-proof';
      final realSdk = FirebaseNativeAuthSdk(
        platform: TargetPlatform.iOS,
        isWeb: false,
        appleBackendFactory: (_) async => backend,
      );
      backend.onSignOut = realSdk.cancel;
      await open(tester, appleClient: realSdk);
      await confirm(tester);
      expect(backend.calls, ['authenticate', 'revoke', 'delete', 'signOut']);
      expect(calls, ['prepare', 'config', 'proof']);
      expect(
        find.textContaining('Deletion completion is not confirmed'),
        findsOneWidget,
      );
      expect(find.textContaining('was not deleted'), findsNothing);
      expect(find.text('Account deletion requested'), findsNothing);
      expect(sessions.value?.token, 'original');
      expect(await receipts.read(), isNotNull);
    },
  );
  deletionWidgetTest(
    'prepared receipt restores without SDK, cleanup or automatic retry',
    (tester) async {
      transport.requiresApple = false;
      transport.status = 'prepared';
      final original = await receipts.prepare(7, 'original');
      await open(tester, statusOnly: true);
      expect(calls, isEmpty);
      expect(sessions.value?.token, 'original');
      expect(find.textContaining('Your request is saved'), findsOneWidget);
      expect(find.text('Account deletion requested'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('request-account-deletion')),
            )
            .onPressed,
        null,
      );
      await confirm(tester);
      expect(calls, ['prepare', 'finalize:false']);
      expect((await receipts.read())?.receipt, original.receipt);
      expect(find.text('Account deletion requested'), findsOneWidget);
    },
  );
  deletionWidgetTest(
    'Android linked account offers action without opening Apple or signing out',
    (tester) async {
      await open(tester);
      await confirm(tester);
      expect(calls, ['prepare']);
      expect(
        find.textContaining('Complete deletion in the iPhone app'),
        findsOneWidget,
      );
      expect(find.text('Account deletion requested'), findsNothing);
      expect(sessions.value?.token, 'original');
      expect(await receipts.read(), isNotNull);
    },
    platform: TargetPlatform.android,
  );
  deletionWidgetTest(
    'ambiguous SDK error preserves receipt and permits status-only recovery',
    (tester) async {
      sdk.failAfterProof = true;
      await open(tester);
      await confirm(tester);
      expect(calls, ['prepare', 'config', 'apple', 'proof']);
      expect(
        find.textContaining('Deletion completion is not confirmed'),
        findsOneWidget,
      );
      expect(find.text('Account deletion requested'), findsNothing);
      expect(sessions.value?.token, 'original');
      final saved = await receipts.read();
      expect(saved, isNotNull);
      transport.status = 'completed';
      final status = find.byKey(const Key('check-deletion-status'));
      await tester.ensureVisible(status);
      await tester.tap(status);
      await tester.pumpAndSettle();
      expect(calls, ['prepare', 'config', 'apple', 'proof']);
      expect(find.text('Account deleted'), findsOneWidget);
      expect(sessions.value, null);
    },
  );
  deletionWidgetTest(
    'SDK success survives lost finalize response and restart without another Apple prompt',
    (tester) async {
      transport.failFinalize = true;
      await open(tester);
      await confirm(tester);
      final saved = await receipts.read();
      expect(saved?.appleCheckpoint?.intentId, 'b' * 64);
      expect(find.text('Account deletion requested'), findsNothing);
      expect(sessions.value?.token, 'original');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      auth = _Auth(sessions.value!);
      receipts = AccountDeletionReceiptStore(
        'https://synthetic.example.invalid',
      );
      transport = _Transport(calls, receipts)..status = 'prepared';
      calls.clear();
      await open(tester, statusOnly: true);
      expect(calls, isEmpty);
      expect(find.textContaining('deletion is not confirmed'), findsOneWidget);
      await confirm(tester);
      expect(calls, ['prepare', 'finalize:true']);
      expect(find.text('Account deletion requested'), findsOneWidget);
      expect(sessions.value, null);
    },
  );
  deletionWidgetTest(
    'saved Apple completion survives fresh same-owner login and a temporary unknown status',
    (tester) async {
      final original = await receipts.prepare(7, 'old');
      await receipts.saveAppleCheckpoint(
        AppleDeletionCheckpoint(
          receipt: original.receipt,
          userId: 7,
          sessionHash: original.sessionHash,
          intentId: 'b' * 64,
        ),
      );
      await open(tester, statusOnly: true);
      expect(find.byKey(const Key('dismiss-deletion-status')), findsNothing);
      expect(sessions.value?.token, 'original');
      await confirm(tester);
      expect(calls, ['prepare', 'finalize:true']);
      expect(
        (await receipts.read())?.appleCheckpoint?.sessionHash,
        AccountDeletionReceipt.hashSession('original'),
      );
      expect(find.text('Account deletion requested'), findsOneWidget);
    },
  );
  deletionWidgetTest(
    'account change during checkpoint persistence blocks finalize and preserves replacement',
    (tester) async {
      final gate = Completer<void>();
      receipts = _DelayedCheckpointStore(gate.future);
      transport = _Transport(calls, receipts);
      await open(tester);
      await confirm(tester, settle: false);
      await tester.pump();
      expect(calls, ['prepare', 'config', 'apple', 'proof', 'revoked']);
      final replacement = _session('replacement', id: 8);
      auth.replace(replacement);
      sessions.value = replacement;
      gate.complete();
      await tester.pumpAndSettle();
      expect(calls.where((s) => s.startsWith('finalize')), isEmpty);
      expect(sessions.value?.token, 'replacement');
      expect((await receipts.read())?.appleCheckpoint?.userId, 7);
      expect(find.text('Account deletion requested'), findsNothing);
      expect(tester.takeException(), null);
    },
  );
  deletionWidgetTest(
    'checkpoint storage failure preserves in-memory SDK completion for explicit retry',
    (tester) async {
      receipts = _FailingCheckpointStore();
      transport = _Transport(calls, receipts);
      await open(tester);
      await confirm(tester);
      expect((await receipts.read())?.appleCheckpoint, null);
      expect(calls.where((s) => s.startsWith('finalize')), isEmpty);
      (receipts as _FailingCheckpointStore).fail = false;
      calls.clear();
      final button = find.byKey(const Key('request-account-deletion'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(calls, ['prepare', 'finalize:true']);
      expect((await receipts.read())?.appleCheckpoint, isNotNull);
      expect(find.text('Account deletion requested'), findsOneWidget);
    },
  );
  deletionWidgetTest(
    'account switch while Apple is open cannot finalize or clear replacement',
    (tester) async {
      final gate = Completer<void>();
      sdk.gate = gate.future;
      await open(tester);
      await confirm(tester, settle: false);
      await tester.pump();
      expect(calls, ['prepare', 'config', 'apple']);
      auth.replace(_session('replacement', id: 8));
      sessions.value = _session('replacement', id: 8);
      gate.complete();
      await tester.pumpAndSettle();
      expect(calls, ['prepare', 'config', 'apple']);
      expect(sessions.value?.token, 'replacement');
      expect(find.text('Account deletion requested'), findsNothing);
      expect(tester.takeException(), null);
    },
  );
  deletionWidgetTest('old transport is never used as a deletion fallback', (
    tester,
  ) async {
    final legacy = _Legacy();
    await open(tester, api: legacy);
    await confirm(tester);
    expect(legacy.calls, 0);
    expect(sessions.value?.token, 'original');
    expect(find.text('Account deletion requested'), findsNothing);
  });
}

class _Auth extends AuthController {
  _Auth(this.initial);
  final AuthSession initial;
  void replace(AuthSession value) => state = AsyncData(value);
  @override
  Future<AuthSession?> build() async => initial;
}

class _Legacy implements CustomerAccountDeletionTransport {
  int calls = 0;
  @override
  Future<Map<String, dynamic>> deletionAvailability() async => {
    'available': true,
  };
  @override
  Future<Map<String, dynamic>> deletionStatus(String receipt) async => {
    'status': 'unknown',
  };
  @override
  Future<Map<String, dynamic>> requestDeletion({
    required String receipt,
    required String expectedSession,
  }) async {
    calls++;
    throw StateError('Old deletion route must not be called');
  }
}

class _Transport extends _Legacy
    implements CustomerAccountIdentityDeletionTransport {
  _Transport(this.steps, this.receipts);
  final List<String> steps;
  final AccountDeletionReceiptStore receipts;
  bool requiresApple = true;
  bool failFinalize = false;
  CustomerAccountTransportException? proofError;
  String status = 'unknown';
  @override
  Future<Map<String, dynamic>> deletionStatus(String receipt) async => {
    'status': status,
  };
  @override
  Future<Map<String, dynamic>> prepareIdentityDeletion({
    required String receipt,
    required String expectedSession,
  }) async {
    expect((await receipts.read())?.receipt, receipt);
    expect((await receipts.read())?.matchesSession(expectedSession), true);
    steps.add('prepare');
    status = 'prepared';
    return {
      'status': 'prepared',
      'user_id': 7,
      'apple_revocation_required': requiresApple,
      'intent_id': 'b' * 64,
    };
  }

  @override
  Future<Map<String, dynamic>> validateAppleDeletion({
    required String receipt,
    required String expectedSession,
    required String idToken,
  }) async {
    steps.add('proof');
    expect(idToken, 'fresh-fixture-proof');
    if (proofError != null) throw proofError!;
    return {'approved': true};
  }

  @override
  Future<Map<String, dynamic>> finalizeIdentityDeletion({
    required String receipt,
    required String expectedSession,
    required bool appleRevoked,
  }) async {
    steps.add('finalize:$appleRevoked');
    if (appleRevoked) {
      final record = await receipts.read();
      expect(record?.appleCheckpoint?.intentId, 'b' * 64);
      expect(
        record?.appleCheckpoint?.sessionHash,
        AccountDeletionReceipt.hashSession(expectedSession),
      );
    }
    if (failFinalize) throw StateError('Synthetic lost connection');
    status = 'pending';
    return {'status': 'pending', 'user_id': 7};
  }
}

class _FailingCheckpointStore extends AccountDeletionReceiptStore {
  _FailingCheckpointStore() : super('https://synthetic.example.invalid');
  bool fail = true;
  @override
  Future<AccountDeletionReceipt> saveAppleCheckpoint(
    AppleDeletionCheckpoint checkpoint,
  ) {
    if (fail) throw StateError('Synthetic storage failure');
    return super.saveAppleCheckpoint(checkpoint);
  }
}

class _DelayedCheckpointStore extends AccountDeletionReceiptStore {
  _DelayedCheckpointStore(this.gate)
    : super('https://synthetic.example.invalid');
  final Future<void> gate;
  @override
  Future<AccountDeletionReceipt> saveAppleCheckpoint(
    AppleDeletionCheckpoint checkpoint,
  ) async {
    await gate;
    return super.saveAppleCheckpoint(checkpoint);
  }
}

class _Apple implements NativeAppleDeletionSdk {
  _Apple(this.calls);
  final List<String> calls;
  bool failAfterProof = false;
  Future<void>? gate;
  @override
  Future<void> deleteAppleIdentity(
    Map<String, dynamic> config, {
    required Future<bool> Function(String) validateIdentity,
    required bool Function() isCurrentAccount,
  }) async {
    expect((config['firebase'] as Map)['projectId'], 'synthetic-project');
    calls.add('apple');
    if (gate != null) await gate;
    if (!isCurrentAccount()) throw const NativeAuthSdkException('cancelled');
    if (!await validateIdentity('fresh-fixture-proof')) {
      throw const NativeAuthSdkException('identity-rejected');
    }
    if (failAfterProof) throw const NativeAuthSdkException('unconfirmed');
    calls.add('revoked');
  }
}

void deletionWidgetTest(
  String label,
  Future<void> Function(WidgetTester) body, {
  TargetPlatform platform = TargetPlatform.iOS,
}) {
  testWidgets(label, body, variant: TargetPlatformVariant.only(platform));
}
