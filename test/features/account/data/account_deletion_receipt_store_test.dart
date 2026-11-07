import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/account/data/storage/account_deletion_receipt_store.dart';

/// Lets a single test force the underlying secure storage write to fail,
/// so we can assert that a failed migration never loses prior evidence.
class _FailingWriteStorage extends FlutterSecureStorage {
  bool failNextWrite = false;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('simulated storage write failure');
    }
    return super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AccountDeletionReceiptStore store;
  final storage = FlutterSecureStorage();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    store = AccountDeletionReceiptStore('https://synthetic.example.invalid');
  });
  AppleDeletionCheckpoint checkpoint(
    AccountDeletionReceipt receipt, {
    String? intent,
    String? token,
  }) => AppleDeletionCheckpoint(
    receipt: receipt.receipt,
    userId: receipt.userId,
    sessionHash: token == null
        ? receipt.sessionHash
        : AccountDeletionReceipt.hashSession(token),
    intentId: intent ?? 'b' * 64,
  );

  test(
    'new receipt reads without checkpoint and persists no raw session',
    () async {
      final original = await store.prepare(7, 'secret-session-fixture');
      expect((await store.read())?.appleCheckpoint, null);
      await store.saveAppleCheckpoint(checkpoint(original));
      final restarted = AccountDeletionReceiptStore(
        'https://synthetic.example.invalid/',
      );
      final read = await restarted.read();
      expect(read?.appleCheckpoint?.receipt, original.receipt);
      expect(read?.appleCheckpoint?.sessionHash, original.sessionHash);
      final raw = (await storage.readAll()).values.single;
      expect(raw, isNot(contains('secret-session-fixture')));
      final value = jsonDecode(raw) as Map;
      expect(
        ((value['records'] as List).single['appleCheckpoint'] as Map).keys
            .toSet(),
        {'receipt', 'userId', 'sessionHash', 'intentId'},
      );
      expect(
        await AccountDeletionReceiptStore(
          'https://another.example.invalid',
        ).read(),
        null,
      );
    },
  );
  test(
    'fresh same-owner session preserves evidence until explicit intent rebind',
    () async {
      final original = await store.prepare(7, 'old');
      await store.saveAppleCheckpoint(checkpoint(original));
      final fresh = await store.prepare(7, 'fresh');
      expect(fresh.receipt, original.receipt);
      expect(fresh.matchesSession('fresh'), true);
      expect(fresh.appleCheckpoint?.sessionHash, original.sessionHash);
      await store.saveAppleCheckpoint(checkpoint(fresh));
      expect(
        (await store.read())?.appleCheckpoint?.sessionHash,
        fresh.sessionHash,
      );
    },
  );
  test(
    'stale SDK callback cannot overwrite a queued replacement session',
    () async {
      final original = await store.prepare(7, 'old');
      final replacement = store.prepare(7, 'fresh');
      final save = store.saveAppleCheckpoint(checkpoint(original));
      await replacement;
      await expectLater(save, throwsStateError);
      expect((await store.read())?.matchesSession('fresh'), true);
      expect((await store.read())?.appleCheckpoint, null);
    },
  );
  test(
    'checkpoint cannot change an already recorded immutable intent',
    () async {
      final original = await store.prepare(7, 'old');
      await store.saveAppleCheckpoint(checkpoint(original));
      await expectLater(
        store.saveAppleCheckpoint(checkpoint(original, intent: 'c' * 64)),
        throwsStateError,
      );
      expect((await store.read())?.appleCheckpoint?.intentId, 'b' * 64);
    },
  );
  test(
    'late checkpoint cannot recreate a cleared receipt or replace another account',
    () async {
      final original = await store.prepare(7, 'old');
      await store.clear(original.receipt);
      await expectLater(
        store.saveAppleCheckpoint(checkpoint(original)),
        throwsStateError,
      );
      final replacement = await store.prepare(8, 'replacement');
      await expectLater(
        store.saveAppleCheckpoint(checkpoint(original)),
        throwsStateError,
      );
      expect((await store.read())?.receipt, replacement.receipt);
      expect((await store.read())?.appleCheckpoint, null);
    },
  );
  for (final field in [
    'receipt',
    'userId',
    'sessionHash',
    'intentId',
    'null',
  ]) {
    test('malformed stored checkpoint fails closed: $field', () async {
      final original = await store.prepare(7, 'original');
      final data = checkpoint(original).toJson();
      if (field != 'null') data[field] = field == 'userId' ? 8 : 'invalid';
      final key = (await storage.readAll()).keys.single;
      await storage.write(
        key: key,
        value: jsonEncode({
          'receipt': original.receipt,
          'userId': original.userId,
          'sessionHash': original.sessionHash,
          'appleCheckpoint': field == 'null' ? null : data,
        }),
      );
      await expectLater(store.read(), throwsFormatException);
      await expectLater(store.prepare(7, 'fresh'), throwsFormatException);
    });
  }

  test(
    'legacy singleton with checkpoint migrates on first write and keeps both owners after restart',
    () async {
      // Establish the real storage key before overwriting it with a
      // hand-authored legacy (pre-collection) payload.
      await store.prepare(7, 'placeholder');
      final key = (await storage.readAll()).keys.single;
      final legacyCheckpoint = AppleDeletionCheckpoint(
        receipt: 'a' * 64,
        userId: 7,
        sessionHash: AccountDeletionReceipt.hashSession('legacy-session'),
        intentId: 'b' * 64,
      );
      await storage.write(
        key: key,
        value: jsonEncode({
          'receipt': legacyCheckpoint.receipt,
          'userId': legacyCheckpoint.userId,
          'sessionHash': legacyCheckpoint.sessionHash,
          'appleCheckpoint': legacyCheckpoint.toJson(),
        }),
      );

      final b = await store.prepare(8, 'fresh-session-b');

      final restarted = AccountDeletionReceiptStore(
        'https://synthetic.example.invalid',
      );
      final a = await restarted.read(userId: 7);
      expect(a?.receipt, legacyCheckpoint.receipt);
      expect(a?.appleCheckpoint?.intentId, legacyCheckpoint.intentId);
      final restartedB = await restarted.read(userId: 8);
      expect(restartedB?.receipt, b.receipt);
      expect(restartedB?.appleCheckpoint, null);
    },
  );

  test(
    'clearing owner B does not alter owner A\'s receipt or checkpoint',
    () async {
      final a = await store.prepare(7, 'session-a');
      await store.saveAppleCheckpoint(checkpoint(a));
      final b = await store.prepare(8, 'session-b');

      await store.clear(b.receipt);

      expect(await store.read(userId: 8), null);
      final stillA = await store.read(userId: 7);
      expect(stillA?.receipt, a.receipt);
      expect(stillA?.appleCheckpoint?.intentId, 'b' * 64);
    },
  );

  test(
    'stale callback cannot overwrite a replacement session nor another owner\'s receipt',
    () async {
      final a = await store.prepare(7, 'old-a');
      final b = await store.prepare(8, 'session-b');
      final replacementA = store.prepare(7, 'fresh-a');
      final staleSave = store.saveAppleCheckpoint(checkpoint(a));
      await replacementA;
      await expectLater(staleSave, throwsStateError);

      expect((await store.read(userId: 7))?.matchesSession('fresh-a'), true);
      expect((await store.read(userId: 7))?.appleCheckpoint, null);
      expect((await store.read(userId: 8))?.receipt, b.receipt);
      expect((await store.read(userId: 8))?.appleCheckpoint, null);
    },
  );

  test(
    'a storage write failure during migration preserves the old singleton and checkpoint',
    () async {
      final failing = _FailingWriteStorage();
      final failingStore = AccountDeletionReceiptStore(
        'https://synthetic.example.invalid',
        storage: failing,
      );
      final original = await failingStore.prepare(7, 'old-session');
      final key = (await storage.readAll()).keys.single;
      await storage.write(
        key: key,
        value: jsonEncode({
          'receipt': original.receipt,
          'userId': original.userId,
          'sessionHash': original.sessionHash,
          'appleCheckpoint': checkpoint(original).toJson(),
        }),
      );
      final rawBefore = (await storage.readAll()).values.single;

      failing.failNextWrite = true;
      await expectLater(
        failingStore.prepare(8, 'new-owner-session'),
        throwsStateError,
      );

      final rawAfter = (await storage.readAll()).values.single;
      expect(rawAfter, rawBefore);
      final restored = await failingStore.read(userId: 7);
      expect(restored?.receipt, original.receipt);
      expect(restored?.appleCheckpoint?.receipt, original.receipt);
      expect(await failingStore.read(userId: 8), null);
    },
  );

  for (final malformed in [
    'version',
    'non-integer-version',
    'records',
    'duplicate-user',
    'duplicate-receipt',
  ]) {
    test('malformed receipt collection fails closed: $malformed', () async {
      await store.prepare(7, 'a');
      await store.prepare(8, 'b');
      final saved = await storage.readAll();
      final data = jsonDecode(saved.values.single) as Map;
      final records = data['records'] as List;
      switch (malformed) {
        case 'version':
          data['version'] = 3;
        case 'non-integer-version':
          data['version'] = 2.0;
        case 'records':
          data['records'] = null;
        case 'duplicate-user':
          records[1]['userId'] = records[0]['userId'];
        case 'duplicate-receipt':
          records[1]['receipt'] = records[0]['receipt'];
      }
      await storage.write(key: saved.keys.single, value: jsonEncode(data));
      await expectLater(store.read(userId: 7), throwsFormatException);
      await expectLater(store.prepare(8, 'fresh'), throwsFormatException);
    });
  }

  test(
    'independent owners A and B are serialized but never block each other',
    () async {
      final storeA = store;
      final pendingA = storeA.prepare(7, 'session-a');
      final pendingB = storeA.prepare(8, 'session-b');

      final a = await pendingA;
      final b = await pendingB;

      expect(a.userId, 7);
      expect(b.userId, 8);
      expect(await storeA.read(userId: 7), isNotNull);
      expect(await storeA.read(userId: 8), isNotNull);
    },
  );

  test(
    'two merchants never share a deletion receipt for the same owner',
    () async {
      final storeA = AccountDeletionReceiptStore(
        'https://merchant-a.example.invalid',
      );
      final storeB = AccountDeletionReceiptStore(
        'https://merchant-b.example.invalid',
      );

      final a = await storeA.prepare(7, 'session-a');
      final b = await storeB.prepare(7, 'session-b');

      expect(a.receipt, isNot(b.receipt));
      expect(await storeA.read(userId: 7), isNotNull);
      expect(await storeB.read(userId: 7), isNotNull);
      await storeA.clear(a.receipt);
      expect(await storeA.read(userId: 7), null);
      expect(await storeB.read(userId: 7), isNotNull);
    },
  );
}
