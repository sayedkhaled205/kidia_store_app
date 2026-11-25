import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/features/product/presentation/product_detail_screen.dart';

import '../support/product_test_data.dart';

class _Images implements BaseCacheManager {
  final file = MemoryFileSystem().file('/original.png');
  Completer<void>? pending;

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool? withProgress = false,
  }) async* {
    if (pending != null) await pending!.future;
    yield FileInfo(
      file,
      FileSource.Cache,
      DateTime.now().add(const Duration(days: 1)),
      url,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Product extends ProductFakeCatalogRepository
    implements CatalogProductImagePreviewSource {
  final pending = Completer<CatalogProduct>();

  @override
  List<CatalogImage> cachedProductImages(int productId) => [
    CatalogImage(
      source: Uri.parse('https://example.com/original-$productId.png'),
    ),
  ];

  @override
  Future<CatalogProduct> getProduct(int productId) => pending.future;
}

Future<void> _flush(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() => CachedNetworkImageProvider.defaultCacheManager = _Images());
  for (final source in ['disk', 'delayed', 'memory']) {
    testWidgets('gallery releases image handles from $source', (tester) async {
      final cache = _Images();
      final oldCache = CachedNetworkImageProvider.defaultCacheManager;
      final oldCreate = ui.Image.onCreate;
      final handles = <ui.Image>[];
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
      final picture = recorder.endRecording();
      await tester.runAsync(() async {
        final image = await picture.toImage(1031, 517);
        cache.file.writeAsBytesSync(
          (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List(),
        );
        image.dispose();
      });
      picture.dispose();
      ui.Image.onCreate = (image) {
        oldCreate?.call(image);
        if (image.width == 1031 && image.height == 517) handles.add(image);
      };
      CachedNetworkImageProvider.defaultCacheManager = cache;
      final fallback = CmsPageLayout.fallback('product');
      final layout = CmsPageLayout(
        page: fallback.page,
        header: fallback.header,
        footer: fallback.footer,
        elements: fallback.elements
            .map(
              (element) => element.type == 'image_gallery'
                  ? CmsPageComponent(
                      id: element.id,
                      type: element.type,
                      enabled: element.enabled,
                      settings: {...element.settings, 'aspect_ratio': 0},
                    )
                  : element,
            )
            .toList(),
      );
      addTearDown(() {
        CachedNetworkImageProvider.defaultCacheManager = oldCache;
        ui.Image.onCreate = oldCreate;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        // Also release any leaked handles when proving the old behavior fails.
        for (final handle in handles) {
          if (!handle.debugDisposed) handle.dispose();
        }
      });

      for (var visit = 0; visit < 3; visit++) {
        cache.pending = source == 'delayed' ? Completer<void>() : null;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cmsPageLayoutProvider(
                'product',
              ).overrideWithValue(AsyncData(layout)),
            ],
            child: MaterialApp(
              home: ProductDetailScreen(
                productId: source == 'memory' ? 41 : 41 + visit,
                repository: _Product(),
              ),
            ),
          ),
        );
        await tester.pump();
        cache.pending?.complete();
        await _flush(tester);
        expect(
          tester
              .widgetList<RawImage>(find.byType(RawImage))
              .any(
                (raw) => raw.image?.width == 1031 && raw.image?.height == 517,
              ),
          isTrue,
          reason: 'The original-resolution photo must actually be displayed.',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        if (source != 'memory' || visit == 2) {
          PaintingBinding.instance.imageCache.clear();
          PaintingBinding.instance.imageCache.clearLiveImages();
        }
        await _flush(tester);
      }
      expect(handles, isNotEmpty);
      expect(
        handles.where((image) => !image.debugDisposed),
        isEmpty,
        reason: 'Leaving product pages must release every image handle.',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
