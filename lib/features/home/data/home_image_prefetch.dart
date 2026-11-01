import 'dart:async';
import 'dart:collection';

/// Warm the existing disk cache while catalog reads are in flight. No decoding
/// or product-image fan-out: rendering and catalog results never await this.
class HomeImagePrefetch {
  HomeImagePrefetch(this.download, {this.concurrency = 4});

  final Future<void> Function(String) download;
  final int concurrency;
  final _queue = Queue<String>();
  final _seen = <String>{};
  var _active = 0;
  var _closed = false;

  void add(Iterable<String> urls) {
    if (_closed) return;
    for (final url in urls) {
      if (_seen.length >= 32) break;
      final uri = Uri.tryParse(url);
      if (uri?.scheme != 'https' || uri!.host.isEmpty || !_seen.add(url)) {
        continue;
      }
      _queue.add(url);
    }
    _pump();
  }

  void _pump() {
    while (!_closed && _active < concurrency && _queue.isNotEmpty) {
      final url = _queue.removeFirst();
      _active++;
      unawaited(
        Future<void>.sync(
          () => download(url),
        ).catchError((Object _) {}).whenComplete(() {
          _active--;
          _pump();
        }),
      );
    }
  }

  void close() {
    _closed = true;
    _queue.clear();
  }
}

/// Design order prioritizes visible content; later hero slides come last.
Iterable<String> staticHomeImageUrls(Map<String, dynamic> home) sync* {
  final laterSlides = <String>[];
  for (final raw in home['blocks'] as List) {
    final block = raw as Map;
    if (block['enabled'] != true || block.containsKey('catalog_query'))
      continue;
    final data = block['data'] as Map;
    switch (block['type']) {
      case 'hero_slider':
        final items = data['items'] as List;
        if (items.isNotEmpty) yield items.first['image_url'] as String;
        laterSlides.addAll(items.skip(1).map((e) => e['image_url'] as String));
      case 'quick_links':
      case 'category_grid':
      case 'banner_grid':
        for (final item in data['items'] as List) {
          yield item['image_url'] as String;
        }
      case 'image_banner':
        yield data['image_url'] as String;
    }
  }
  yield* laterSlides;
}
