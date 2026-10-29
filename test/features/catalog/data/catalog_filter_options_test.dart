import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/features/catalog/data/datasources/store_api_filter_options.dart';
import 'package:mobishop_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';

class _Client implements StoreApiClient {
  _Client(this.reply);
  final Future<StoreApiResponse> Function(String, Map<String, dynamic>) reply;
  final List<String> calls = [];
  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) {
    calls.add(path);
    return reply(path, queryParameters ?? {});
  }
}

StoreApiResponse response(List data, {int? pages}) => StoreApiResponse(
  data: data,
  headers: {
    if (pages != null) 'x-wp-totalpages': ['$pages'],
  },
);

void main() {
  test(
    'malformed imported markup is omitted and readable labels stay intact',
    () {
      expect(catalogFilterLabel('i/>'), '');
      expect(catalogFilterLabel('i class="fa fa-lock">'), '');
      expect(catalogFilterLabel('<b>Kids &amp; Baby</b>'), 'Kids & Baby');
      expect(catalogFilterLabel('0–3m'), '0–3m');
    },
  );
  test(
    'fetches every tag page and exact Arabic size taxonomy and slugs',
    () async {
      final client = _Client((path, query) async {
        expect(query['hide_empty'], true);
        if (path.endsWith('/tags')) {
          return response([
            for (
              var id = (query['page'] as int) - 1;
              id < (query['page'] as int) + 1;
              id++
            )
              {'id': id + 1, 'name': 'Tag ${id + 1}'},
          ], pages: 2);
        }
        if (path.endsWith('/attributes')) {
          return response([
            {'id': 8, 'taxonomy': 'pa_المقاس', 'name': 'المقاس'},
            {'id': 9, 'taxonomy': 'pa_colour', 'name': 'Colour'},
            {'id': 10, 'taxonomy': 'pa_material', 'name': 'Material'},
          ]);
        }
        return response([
          {
            'id': 2,
            'name': path.contains('/8/') ? '0–3m' : 'Blue',
            'slug': path.contains('/8/') ? '0-3m' : 'blue',
          },
        ]);
      });
      final options = await StoreApiFilterOptions(client).getFilterOptions();
      expect(options.tags.map((v) => v.id), [1, 2, 3]);
      expect(options.sizes.single.taxonomy, 'pa_المقاس');
      expect(options.sizes.single.term, '0-3m');
      expect(options.colors.single.term, 'blue');
      expect(client.calls.length, 5);
      expect(client.calls.any((v) => v.contains('/10/')), false);
    },
  );
  test('malformed response and repeated pagination fail visibly', () async {
    final bad = _Client(
      (p, q) async => const StoreApiResponse(data: {'error': 'bad'}),
    );
    await expectLater(
      StoreApiFilterOptions(bad).getFilterOptions(),
      throwsFormatException,
    );
    final repeat = _Client(
      (p, q) async => response([
        {'id': 1, 'name': 'Tag'},
      ], pages: 20),
    );
    await expectLater(
      StoreApiFilterOptions(repeat).getFilterOptions(),
      throwsFormatException,
    );
    expect(repeat.calls.length, lessThanOrEqualTo(4));
  });
  test('deadline stops loading without scheduling further pages', () async {
    final client = _Client((p, q) => Completer<StoreApiResponse>().future);
    await expectLater(
      StoreApiFilterOptions(
        client,
        budget: const Duration(milliseconds: 10),
      ).getFilterOptions(),
      throwsA(isA<TimeoutException>()),
    );
    expect(client.calls.length, 2);
  });
  test(
    'tags are deduplicated and selection order does not reload products',
    () {
      const a = CatalogTagOption(id: 2, label: 'Jacket'),
          b = CatalogTagOption(id: 1, label: 'Trousers');
      const first = CatalogProductFilters(tags: [a, b, a]);
      const second = CatalogProductFilters(tags: [b, a]);
      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first.activeCount, 2);
      expect(
        first
            .withOptions(
              sizes: const [
                CatalogSizeOption(
                  taxonomy: 'pa_size',
                  term: 's',
                  label: 'Small',
                ),
              ],
            )
            .tags,
        [b, a],
      );
    },
  );
}
