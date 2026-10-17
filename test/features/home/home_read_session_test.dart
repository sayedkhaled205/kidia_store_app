import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/home/data/home_read_session.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_layout.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/core/network/store_api_exception.dart';

void main() {
  HomeLayout home() => HomeLayout(
    version: 1,
    page: 'home',
    locale: 'ar',
    updatedAt: DateTime(2026),
    blocks: [],
  );
  const connection = CatalogRepositoryException(
    kind: StoreApiFailureKind.connection,
    message: 'offline',
  );
  const unauthorized = CatalogRepositoryException(
    kind: StoreApiFailureKind.unauthorized,
    message: 'denied',
  );
  test(
    'retry initial transient read once, then retain real content on refresh failure',
    () async {
      final session = HomeReadSession();
      final layout = home();
      var calls = 0;
      expect(
        await session.load('ar', () async {
          if (++calls == 1) throw connection;
          return layout;
        }, pause: () async {}),
        same(layout),
      );
      expect(calls, 2);
      expect(session.isStale('ar'), false);
      expect(
        await session.load(
          'ar',
          () async => throw connection,
          pause: () async {},
        ),
        same(layout),
      );
      expect(session.isStale('ar'), true);
      await session.load('ar', () async => layout);
      expect(session.isStale('ar'), false);
    },
  );
  test('never invent first-load content or reuse another locale', () async {
    final session = HomeReadSession();
    await session.load('ar', () async => home());
    await expectLater(
      session.load('en', () async => throw connection, pause: () async {}),
      throwsA(same(connection)),
    );
  });
  test(
    'authorization failure is not retried or concealed with cached content',
    () async {
      final session = HomeReadSession();
      await session.load('ar', () async => home());
      var calls = 0;
      await expectLater(
        session.load('ar', () async {
          calls++;
          throw unauthorized;
        }),
        throwsA(same(unauthorized)),
      );
      expect(calls, 1);
      expect(session.isStale('ar'), false);
      await expectLater(
        session.load('ar', () async => throw connection, pause: () async {}),
        throwsA(same(connection)),
      );
    },
  );
}
