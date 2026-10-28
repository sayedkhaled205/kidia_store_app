import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/app_design_hydration58.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_layout.dart';

import 'app_design_fixture58.dart';

class _TimedCatalog implements CatalogRepository {
  int calls = 0;
  int active = 0;
  int peak = 0;

  @override
  Future<CatalogPage<CatalogProduct>> getProducts(
    CatalogProductQuery query,
  ) async {
    calls++;
    active++;
    if (active > peak) peak = active;
    await Future<void>.delayed(const Duration(milliseconds: 600));
    active--;
    return const CatalogPage(
      items: <CatalogProduct>[],
      page: 1,
      perPage: 8,
      totalItems: 0,
      totalPages: 0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets(
    'distinct selectors remain bounded and a new locale reads fresh data',
    (tester) async {
      final home = appDesignMap58(appDesignFixture58()['home']);
      final template = appDesignMap58((home['blocks'] as List)[1]);
      home['blocks'] = [
        for (var i = 0; i < 6; i++)
          {
            ...template,
            'id': 'unique-$i',
            'catalog_query': {
              ...appDesignMap58(template['catalog_query']),
              'limit': i + 1,
            },
          },
      ];
      final repository = _TimedCatalog();
      for (final locale in ['en', 'ar']) {
        HomeLayout? result;
        final loading = hydrateSavedHome58(
          home,
          repository,
          locale: locale,
        ).then((value) => result = value);
        await tester.pump();
        for (var wave = 0; result == null && wave < 8; wave++) {
          await tester.pump(const Duration(milliseconds: 600));
        }
        await loading;
        expect(result?.blocks.length, 6);
        expect(repository.peak, 3);
        expect(repository.active, 0);
      }
      expect(
        repository.calls,
        12,
        reason: 'No cross-refresh or cross-language cache',
      );
    },
  );
  testWidgets('controlled six-section home hydration probe', (tester) async {
    final home = appDesignMap58(appDesignFixture58()['home']);
    final template = appDesignMap58((home['blocks'] as List)[1]);
    home['blocks'] = [
      for (var i = 0; i < 6; i++) {...template, 'id': 'probe-$i'},
    ];
    final repository = _TimedCatalog();
    HomeLayout? result;
    final loading = hydrateSavedHome58(
      home,
      repository,
      locale: 'ar',
    ).then((value) => result = value);
    await tester.pump();
    var waves = 0;
    while (result == null && waves < 8) {
      await tester.pump(const Duration(milliseconds: 600));
      waves++;
    }
    expect(result, isNotNull, reason: 'Home must finish within eight waves.');
    await loading;
    expect(result?.blocks.length, 6);
    expect(repository.calls, 1);
    expect(repository.active, 0);
    expect(repository.peak, 1);
    expect(waves, 1);
    // Diagnostic output is a deterministic network-delay simulation, not a
    // measurement of a physical phone or production network.
    // ignore: avoid_print
    print(
      'HOME_HYDRATION_PROBE ${jsonEncode({'sections': 6, 'delay_per_request_ms': 600, 'requests': repository.calls, 'peak_concurrent': repository.peak, 'waves': waves, 'simulated_completion_ms': waves * 600})}',
    );
  });
}
