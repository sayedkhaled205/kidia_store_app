import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/memory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_image.dart';
import 'package:mobishop_store_app/features/product/presentation/product_image_gallery.dart';

import 'package:mobishop_store_app/shared/widgets/common/app_network_image.dart';

class _ControlledImages implements BaseCacheManager {
  final requests = <String>[];
  final pending = <Completer<FileInfo>>[];
  final file = MemoryFileSystem().file('/original.png');

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool? withProgress = false,
  }) async* {
    requests.add(url);
    final request = Completer<FileInfo>();
    pending.add(request);
    yield await request.future;
  }

  void fail(int index) => pending[index].completeError(
    const SocketException('isolated simulated network failure'),
  );

  void succeed(int index) => pending[index].complete(
    FileInfo(
      file,
      FileSource.Cache,
      DateTime.now().add(const Duration(days: 1)),
      requests[index],
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _flush(WidgetTester tester, {int frames = 6}) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<_ControlledImages> _setup(WidgetTester tester) async {
  final cache = _ControlledImages();
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
  final picture = recorder.endRecording();
  await tester.runAsync(() async {
    final image = await picture.toImage(640, 480);
    cache.file.writeAsBytesSync(
      (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!.buffer.asUint8List(),
    );
    image.dispose();
  });
  picture.dispose();
  CachedNetworkImageProvider.defaultCacheManager = cache;
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  addTearDown(() {
    for (var i = 0; i < cache.pending.length; i++) {
      if (!cache.pending[i].isCompleted) cache.fail(i);
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  return cache;
}

void _resume(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Widget _app(
  bool displaySized, {
  String url = 'https://example.com/full-original.png',
  bool active = true,
  Widget? errorWidget,
  Key? imageKey,
}) => MaterialApp(
  home: Scaffold(
    body: TickerMode(
      enabled: active,
      child: Center(
        child: AppNetworkImage(
          key: imageKey,
          imageUrl: url,
          width: 200,
          height: 150,
          decodeAtDisplaySize: displaySized,
          errorWidget: errorWidget,
        ),
      ),
    ),
  ),
);

bool _hasDecodedImage(WidgetTester tester) => tester
    .widgetList<RawImage>(find.byType(RawImage))
    .any((image) => image.image != null);

void main() {
  setUpAll(() {
    CachedNetworkImageProvider.defaultCacheManager = _ControlledImages();
  });

  for (final displaySized in [false, true]) {
    final mode = displaySized ? 'display-sized' : 'original';

    testWidgets(
      '$mode failed tap retries once and preserves original URL and decode contract',
      (tester) async {
        final cache = await _setup(tester);
        await tester.pumpWidget(_app(displaySized));
        await _flush(tester);
        cache.fail(0);
        await _flush(tester);
        expect(find.byType(AppNetworkImageError), findsOneWidget);
        await tester.tap(find.byType(AppNetworkImageError));
        await _flush(tester);
        expect(cache.requests, [
          'https://example.com/full-original.png',
          'https://example.com/full-original.png',
        ]);
        expect(find.byType(AppNetworkImageError), findsNothing);
        // Repeated interaction/lifecycle while retry is still pending does not fan out.
        await tester.tap(find.byType(AppNetworkImage));
        await tester.tap(find.byType(AppNetworkImage));
        _resume(tester);
        await _flush(tester);
        expect(cache.requests.length, 2);
        cache.succeed(1);
        await _flush(tester);
        expect(_hasDecodedImage(tester), isTrue);
        final decoded = tester
            .widgetList<RawImage>(find.byType(RawImage))
            .firstWhere((x) => x.image != null)
            .image!;
        if (!displaySized) {
          expect(decoded.width, 640);
          expect(decoded.height, 480);
        }
        expect(find.byType(AppNetworkImageError), findsNothing);
        _resume(tester);
        await _flush(tester);
        expect(
          cache.requests.length,
          2,
          reason: 'A healthy image does not refresh on foreground',
        );
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      '$mode second failure has no retry loop and same URL rebuild does not retry',
      (tester) async {
        final cache = await _setup(tester);
        await tester.pumpWidget(_app(displaySized));
        await _flush(tester);
        cache.fail(0);
        await _flush(tester);
        await tester.tap(find.byType(AppNetworkImageError));
        await _flush(tester);
        expect(cache.requests.length, 2);
        cache.fail(1);
        await _flush(tester);
        await tester.pump(const Duration(minutes: 2));
        await tester.pumpWidget(_app(displaySized));
        await _flush(tester);
        expect(cache.requests.length, 2);
        expect(find.byType(AppNetworkImageError), findsOneWidget);
        await tester.tap(find.byType(AppNetworkImageError));
        await _flush(tester);
        expect(cache.requests.length, 3);
        cache.succeed(2);
        await _flush(tester);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('$mode paused to resumed retries a failed image once', (
      tester,
    ) async {
      final cache = await _setup(tester);
      await tester.pumpWidget(_app(displaySized));
      await _flush(tester);
      cache.fail(0);
      await _flush(tester);
      _resume(tester);
      await _flush(tester);
      expect(cache.requests.length, 2);
      cache.fail(1);
      await _flush(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _flush(tester);
      expect(
        cache.requests.length,
        2,
        reason: 'Duplicate resumed is not another background cycle',
      );
      _resume(tester);
      await _flush(tester);
      expect(cache.requests.length, 3);
      cache.succeed(2);
      await _flush(tester);
      expect(_hasDecodedImage(tester), isTrue);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      '$mode inactive TickerMode does not refresh failed image on resume',
      (tester) async {
        final cache = await _setup(tester);
        await tester.pumpWidget(_app(displaySized, active: false));
        await _flush(tester);
        cache.fail(0);
        await _flush(tester);
        _resume(tester);
        await _flush(tester);
        expect(cache.requests.length, 1);
        await tester.pumpWidget(_app(displaySized));
        await _flush(tester);
        // Flutter may resolve the image again when TickerMode dependencies change.
        // This activation is separate from the covered foreground event above.
        if (cache.requests.length == 1) {
          await tester.tap(find.byType(AppNetworkImageError));
          await _flush(tester);
        }
        expect(cache.requests.length, 2);
        cache.succeed(1);
        await _flush(tester);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('$mode covered route does not refresh failed image on resume', (
      tester,
    ) async {
      final cache = await _setup(tester);
      await tester.pumpWidget(_app(displaySized));
      await _flush(tester);
      cache.fail(0);
      await _flush(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Cover')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Route dependency changes themselves can trigger a normal resolution.
      // Fail any such reads, then isolate the foreground event while covered.
      for (var i = 0; i < cache.pending.length; i++) {
        if (!cache.pending[i].isCompleted) cache.fail(i);
      }
      await _flush(tester);
      final beforeResume = cache.requests.length;
      _resume(tester);
      await _flush(tester);
      expect(cache.requests.length, beforeResume);
      navigator.pop();
      await _flush(tester);
      for (var i = 0; i < cache.pending.length; i++) {
        if (!cache.pending[i].isCompleted) cache.succeed(i);
      }
      await _flush(tester);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      '$mode changing URL resets failure while the new original loads',
      (tester) async {
        final cache = await _setup(tester);
        await tester.pumpWidget(_app(displaySized));
        await _flush(tester);
        cache.fail(0);
        await _flush(tester);
        const newUrl = 'https://example.com/new-original.png';
        await tester.pumpWidget(_app(displaySized, url: newUrl));
        await _flush(tester);
        expect(cache.requests.length, 2);
        expect(cache.requests.last, newUrl);
        _resume(tester);
        await _flush(tester);
        expect(cache.requests.length, 2);
        cache.succeed(1);
        await _flush(tester);
        expect(_hasDecodedImage(tester), isTrue);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('$mode disposed failure is not retried on resume', (
      tester,
    ) async {
      final cache = await _setup(tester);
      await tester.pumpWidget(_app(displaySized));
      await _flush(tester);
      cache.fail(0);
      await _flush(tester);
      await tester.pumpWidget(const SizedBox());
      _resume(tester);
      await _flush(tester);
      expect(cache.requests.length, 1);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '$mode custom fallback is retained and tappable; empty URL never requests',
      (tester) async {
        final cache = await _setup(tester);
        const custom = SizedBox(
          width: 150,
          height: 100,
          child: Text('Custom fallback'),
        );
        await tester.pumpWidget(_app(displaySized, errorWidget: custom));
        await _flush(tester);
        cache.fail(0);
        await _flush(tester);
        expect(find.text('Custom fallback'), findsOneWidget);
        expect(find.byTooltip('Retry image'), findsOneWidget);
        await tester.tap(find.text('Custom fallback'));
        await _flush(tester);
        expect(cache.requests.length, 2);
        cache.succeed(1);
        await _flush(tester);
        await tester.pumpWidget(
          _app(displaySized, url: '', errorWidget: custom),
        );
        await _flush(tester);
        expect(find.text('Custom fallback'), findsOneWidget);
        expect(find.byTooltip('Retry image'), findsNothing);
        _resume(tester);
        await _flush(tester);
        expect(cache.requests.length, 2);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'fullscreen retry keeps selected page controller, zoom and original dimensions',
    (tester) async {
      final cache = await _setup(tester);
      final images = List.generate(
        3,
        (i) =>
            CatalogImage(source: Uri.parse('https://example.com/full-$i.png')),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ProductImageGallery(
            images: images,
            productName: 'Public fixture',
            initialIndex: 1,
          ),
        ),
      );
      await _flush(tester);
      final originalIndex = cache.requests.indexOf(
        'https://example.com/full-1.png',
      );
      expect(originalIndex, greaterThanOrEqualTo(0));
      for (var i = 0; i < cache.pending.length; i++) {
        if (i == originalIndex) {
          cache.fail(i);
        } else {
          cache.succeed(i);
        }
      }
      await _flush(tester);
      final before = tester.widget<PageView>(
        find.byKey(const Key('fullscreen-gallery-pages')),
      );
      final zoom = tester
          .widget<InteractiveViewer>(
            find.byKey(const Key('fullscreen-image-zoom')),
          )
          .transformationController!;
      zoom.value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.pump();
      await tester.tapAt(
        tester.getCenter(find.byKey(const Key('fullscreen-image-zoom'))),
      );
      await _flush(tester);
      final retried = cache.requests.lastIndexOf(
        'https://example.com/full-1.png',
      );
      expect(retried, greaterThan(originalIndex));
      cache.succeed(retried);
      await _flush(tester);
      final after = tester.widget<PageView>(
        find.byKey(const Key('fullscreen-gallery-pages')),
      );
      expect(after.controller, same(before.controller));
      expect(after.controller!.page, 1);
      expect(zoom.value.getMaxScaleOnAxis(), 2);
      final raw = tester
          .widgetList<RawImage>(find.byType(RawImage))
          .firstWhere((x) => x.image != null)
          .image!;
      expect(raw.width, 640);
      expect(raw.height, 480);
      expect(find.text('2 / 3'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    },
  );
}
