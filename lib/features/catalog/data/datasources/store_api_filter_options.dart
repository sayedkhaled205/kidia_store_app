import 'dart:async';
import 'package:mobishop_store_app/core/network/store_api_client.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_filter_options.dart';

class StoreApiFilterOptions implements CatalogFilterOptionsSource {
  const StoreApiFilterOptions(
    this.client, {
    this.budget = const Duration(seconds: 12),
  });
  final StoreApiClient client;
  final Duration budget;

  @override
  Future<CatalogFilterOptions> getFilterOptions() async {
    final clock = Stopwatch()..start();
    final values = await Future.wait([
      _terms('/wp-json/wc/store/v1/products/tags', clock),
      _terms('/wp-json/wc/store/v1/products/attributes', clock),
    ]);
    final sizes = <CatalogSizeOption>[];
    final colors = <CatalogSizeOption>[];
    for (final attribute in values[1]) {
      final id = int.tryParse('${attribute['id']}') ?? 0;
      final taxonomy = '${attribute['taxonomy'] ?? ''}';
      final name = '$taxonomy ${attribute['name']}'.toLowerCase();
      final isSize = RegExp(r'size|مقاس').hasMatch(name);
      final isColor = RegExp(r'colou?r|لون|الوان|ألوان').hasMatch(name);
      if (id <= 0 || !taxonomy.startsWith('pa_') || (!isSize && !isColor)) {
        continue;
      }
      final terms = await _terms(
        '/wp-json/wc/store/v1/products/attributes/$id/terms',
        clock,
      );
      final target = isSize ? sizes : colors;
      for (final term in terms) {
        final slug = '${term['slug'] ?? ''}';
        final label = catalogFilterLabel(term['name'] ?? slug);
        if (slug.isNotEmpty && label.isNotEmpty) {
          target.add(
            CatalogSizeOption(taxonomy: taxonomy, term: slug, label: label),
          );
        }
      }
    }
    return CatalogFilterOptions(
      tags: [
        for (final tag in values[0])
          if ((int.tryParse('${tag['id']}') ?? 0) > 0 &&
              catalogFilterLabel(tag['name']).isNotEmpty)
            CatalogTagOption(
              id: int.parse('${tag['id']}'),
              label: catalogFilterLabel(tag['name']),
            ),
      ],
      sizes: sizes,
      colors: colors,
    );
  }

  Future<List<Map<String, dynamic>>> _terms(
    String path,
    Stopwatch clock,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    for (var page = 1; page <= 50; page++) {
      final remaining = budget - clock.elapsed;
      if (remaining <= Duration.zero) {
        throw TimeoutException('Catalog filters timed out');
      }
      final response = await client
          .get(
            path,
            queryParameters: {
              'per_page': 100,
              'page': page,
              'hide_empty': true,
              'orderby': 'name',
              'order': 'asc',
            },
          )
          .timeout(remaining);
      if (response.data is! List) {
        throw const FormatException('Invalid catalog filter response');
      }
      final items = response.data as List;
      final before = result.length;
      for (final item in items) {
        if (item is Map<String, dynamic> &&
            (int.tryParse('${item['id']}') ?? 0) > 0) {
          result['${item['id']}'] = item;
        }
      }
      final total = int.tryParse(response.header('x-wp-totalpages') ?? '');
      if (total != null ? page >= total : items.length < 100) {
        return List.unmodifiable(result.values);
      }
      if (items.isEmpty || before == result.length) {
        throw const FormatException('Catalog filter pagination repeated');
      }
    }
    throw const FormatException('Catalog filter pagination did not finish');
  }
}
