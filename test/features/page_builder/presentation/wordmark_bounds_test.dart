import 'dart:typed_data';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/shared/widgets/common/wordmark_image.dart';

void main() {
  testWidgets('late logo failure after closing screen is handled', (
    tester,
  ) async {
    final old = CachedNetworkImageProvider.defaultCacheManager;
    final cache = _DelayedLogoCache();
    CachedNetworkImageProvider.defaultCacheManager = cache;
    addTearDown(() {
      CachedNetworkImageProvider.defaultCacheManager = old;
      PaintingBinding.instance.imageCache.clear();
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: WordmarkImage(
          url: 'https://merchant.example/late-logo.png',
          width: 160,
          height: 56,
          fallback: Text('Merchant'),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    cache.result.addError(StateError('Synthetic late image failure'));
    await cache.result.close();
    await tester.pump();
    expect(tester.takeException(), null);
  });
  test(
    'saved logo geometry has the same aspect in native and web previews',
    () {
      expect(
        wordmarkAspectRatio(
          'https://store.example/logo.png#wm=0.04,0.25,0.91,0.5,2.95',
        ),
        2.95,
      );
      expect(wordmarkAspectRatio('https://store.example/logo.png'), 0);
      expect(
        wordmarkAspectRatio('https://store.example/logo.png#wm=0,0,1,1,NaN'),
        0,
      );
    },
  );
  test(
    'transparent padding is excluded without cutting visible logo pixels',
    () {
      final pixels = Uint8List(100 * 100 * 4);
      for (var y = 30; y < 70; y++) {
        for (var x = 10; x < 90; x++) {
          pixels[(y * 100 + x) * 4 + 3] = 255;
        }
      }
      expect(
        visibleWordmarkBounds(pixels, 100, 100),
        const Rect.fromLTRB(10, 30, 90, 70),
      );
      final fitted = applyBoxFit(
        BoxFit.contain,
        const Size(80, 40),
        const Size(160, 56),
      );
      expect(fitted.destination, const Size(112, 56));
    },
  );
  test('opaque or empty logo retains its full image bounds', () {
    for (final alpha in [0, 255]) {
      final pixels = Uint8List(20 * 10 * 4);
      for (var i = 3; i < pixels.length; i += 4) {
        pixels[i] = alpha;
      }
      expect(
        visibleWordmarkBounds(pixels, 20, 10),
        const Rect.fromLTWH(0, 0, 20, 10),
      );
    }
  });
  test('opaque light canvas is trimmed without removing colored artwork', () {
    for (final background in [230, 255]) {
      final pixels = Uint8List(100 * 100 * 4);
      for (var i = 0; i < pixels.length; i += 4) {
        pixels[i] = pixels[i + 1] = pixels[i + 2] = background;
        pixels[i + 3] = 255;
      }
      for (var y = 30; y < 70; y++) {
        for (var x = 10; x < 90; x++) {
          pixels[(y * 100 + x) * 4] = 30;
        }
      }
      expect(
        visibleWordmarkBounds(pixels, 100, 100),
        const Rect.fromLTRB(10, 30, 90, 70),
      );
    }
  });
}

class _DelayedLogoCache implements BaseCacheManager {
  final result = StreamController<FileResponse>();
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) => result.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
