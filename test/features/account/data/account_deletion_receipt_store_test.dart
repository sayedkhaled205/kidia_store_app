import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/account/data/storage/account_deletion_receipt_store.dart';

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
    'legacy receipt reads without checkpoint and new record persists no raw session',
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
      expect((value['appleCheckpoint'] as Map).keys.toSet(), {
        'receipt',
        'userId',
        'sessionHash',
        'intentId',
      });
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
}
