import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/catalog/data/repositories/cms_preview_catalog_repository.dart';

void main() {
  test(
    'preview brands and facets share the authenticated reader and refresh together',
    () async {
      var revision = 1, calls = 0;
      final pending = Completer<Map<String, dynamic>>();
      final repository = CmsPreviewCatalogRepository(
        live: true,
        revision: () => revision,
        fetchPage: (query) {
          calls++;
          expect(query, {'catalog_resource': 'filter_options'});
          return pending.future;
        },
      );
      final brands = repository.getFilterBrands();
      final facets = repository.getFilterOptions();
      expect(calls, 1);
      pending.complete({
        'filter_options': {
          'brands': [
            {'id': 5, 'name': 'Kids', 'slug': 'kids', 'count': 3},
            {'id': 0},
          ],
          'tags': [
            {'id': 7, 'label': 'Trousers'},
          ],
        },
      });
      expect((await brands).single.id, 5);
      expect((await facets).tags.single.id, 7);
      await repository.getFilterBrands();
      expect(calls, 1);
      revision++;
      await repository.getFilterBrands();
      expect(calls, 2);
    },
  );
  test(
    'failed preview facets remain retryable, demo never contacts store',
    () async {
      var calls = 0;
      final repository = CmsPreviewCatalogRepository(
        live: true,
        revision: () => 1,
        fetchPage: (query) async {
          calls++;
          return calls == 1
              ? {'error': 'Unavailable'}
              : {
                  'filter_options': {'brands': []},
                };
        },
      );
      await expectLater(repository.getFilterBrands(), throwsStateError);
      expect(await repository.getFilterBrands(), isEmpty);
      expect(calls, 2);
      final demo = CmsPreviewCatalogRepository(
        live: false,
        fetchPage: (_) {
          throw StateError('Demo must not call');
        },
      );
      expect(await demo.getFilterBrands(), isEmpty);
    },
  );
}
