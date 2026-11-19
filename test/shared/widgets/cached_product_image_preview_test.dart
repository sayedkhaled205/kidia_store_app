import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/shared/widgets/common/app_network_image.dart';
import 'package:mobishop_store_app/shared/widgets/common/cached_product_image_preview.dart';

File _cachedFile(Uint8List bytes) {
  final fs = const LocalFileSystem();
  final directory = fs.systemTempDirectory.createTempSync(
    'kidia-preview-test-',
  );
  addTearDown(() {
    final root = fs.systemTempDirectory.resolveSymbolicLinksSync();
    final resolved = directory.resolveSymbolicLinksSync();
    if (!resolved.startsWith('$root${fs.path.separator}kidia-preview-test-')) {
      throw StateError('Unexpected test directory');
    }
    directory.deleteSync(recursive: true);
  });
  return directory.childFile('preview.png')..writeAsBytesSync(bytes);
}

/// Fails the test if anything other than [getFileFromCache] is called, so a
/// regression that reaches for the network is caught immediately.
class _FakeCacheManager implements BaseCacheManager {
  _FakeCacheManager() {
    addTearDown(() => expect(unexpectedMethods, isEmpty));
  }

  final List<Symbol> unexpectedMethods = [];
  int callCount = 0;
  final List<String> calledUrls = [];
  final Map<String, Completer<FileInfo?>> _pending = {};

  Completer<FileInfo?> completerFor(String url) =>
      _pending.putIfAbsent(url, () => Completer<FileInfo?>());

  @override
  Future<FileInfo?> getFileFromCache(
    String key, {
    bool ignoreMemCache = false,
  }) {
    callCount++;
    calledUrls.add(key);
    return completerFor(key).future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    unexpectedMethods.add(invocation.memberName);
    throw StateError(
      'Unexpected cache manager method: ${invocation.memberName}',
    );
  }
}

class _OriginalCacheManager extends _FakeCacheManager {
  final original = Completer<FileInfo>();
  final requestedUrls = <String>[];

  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool? withProgress = false,
  }) async* {
    requestedUrls.add(url);
    yield await original.future;
  }
}

Future<Uint8List> _validPngBytes(WidgetTester tester) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawColor(Colors.blue, BlendMode.src);
  final picture = recorder.endRecording();
  final bytes = (await tester.runAsync(() async {
    final image = await picture.toImage(40, 40);
    final data = (await image.toByteData(
      format: ui.ImageByteFormat.png,
    ))!.buffer.asUint8List();
    image.dispose();
    return data;
  }))!;
  picture.dispose();
  return bytes;
}

FileInfo _validInfo(File file, String url) => FileInfo(
  file,
  FileSource.Cache,
  DateTime.now().add(const Duration(days: 1)),
  url,
);

FileInfo _expiredInfo(File file, String url) => FileInfo(
  file,
  FileSource.Cache,
  DateTime.now().subtract(const Duration(days: 1)),
  url,
);

/// Bounded wait for the decoded image to appear, instead of pumpAndSettle
/// which never settles while the loading shimmer animation is repeating.
Future<void> _pumpUntilImageDecoded(WidgetTester tester) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    if (tester
        .widgetList<RawImage>(find.byType(RawImage))
        .any((image) => image.image != null)) {
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

Future<void> _pumpSettledFrames(WidgetTester tester, {int frames = 5}) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
}

void main() {
  setUpAll(() {
    // Do not initialize the platform-backed default cache in widget tests.
    CachedNetworkImageProvider.defaultCacheManager = _FakeCacheManager();
  });
  tearDown(() => PaintingBinding.instance.imageCache.clear());

  for (final failOriginal in [false, true]) {
    testWidgets(
      'cached preview precedes original and yields to its ${failOriginal ? 'error' : 'image'}',
      (tester) async {
        final manager = _OriginalCacheManager();
        final previous = CachedNetworkImageProvider.defaultCacheManager;
        CachedNetworkImageProvider.defaultCacheManager = manager;
        addTearDown(
          () => CachedNetworkImageProvider.defaultCacheManager = previous,
        );
        final bytes = await _validPngBytes(tester);
        final source = 'https://example.com/original-$failOriginal.jpg';
        final preview = 'https://example.com/card-$failOriginal.jpg';
        manager
            .completerFor(preview)
            .complete(_validInfo(_cachedFile(bytes), preview));
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: AppNetworkImage(
                  imageUrl: source,
                  placeholder: CachedProductImagePreview(imageUrl: preview),
                ),
              ),
            ),
          ),
        );
        await _pumpUntilImageDecoded(tester);
        expect(find.byType(CachedProductImagePreview), findsOneWidget);
        expect(
          tester
              .widgetList<RawImage>(find.byType(RawImage))
              .any((i) => i.image != null),
          isTrue,
        );
        expect(manager.requestedUrls, [source]);
        expect(manager.original.isCompleted, isFalse);
        if (failOriginal) {
          manager.original.completeError(StateError('Original unavailable'));
        } else {
          manager.original.complete(_validInfo(_cachedFile(bytes), source));
        }
        await _pumpSettledFrames(tester, frames: 20);
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(CachedProductImagePreview), findsNothing);
        expect(
          find.byType(AppNetworkImageError),
          failOriginal ? findsOneWidget : findsNothing,
        );
        expect(manager.requestedUrls, [source]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('cache hit renders the cached file pixels', (tester) async {
    final manager = _FakeCacheManager();
    final bytes = await _validPngBytes(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: CachedProductImagePreview(
          imageUrl: 'https://example.com/a.jpg',
          cacheManager: manager,
        ),
      ),
    );
    manager
        .completerFor('https://example.com/a.jpg')
        .complete(_validInfo(_cachedFile(bytes), 'https://example.com/a.jpg'));
    await _pumpUntilImageDecoded(tester);

    expect(
      tester
          .widgetList<RawImage>(find.byType(RawImage))
          .any((image) => image.image != null),
      isTrue,
    );
    expect(manager.callCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cache miss shows the loading placeholder without any network call',
    (tester) async {
      final manager = _FakeCacheManager();

      await tester.pumpWidget(
        MaterialApp(
          home: CachedProductImagePreview(
            imageUrl: 'https://example.com/missing.jpg',
            cacheManager: manager,
          ),
        ),
      );
      manager.completerFor('https://example.com/missing.jpg').complete(null);
      await _pumpSettledFrames(tester);

      expect(find.byType(AppNetworkImageLoading), findsOneWidget);
      expect(manager.callCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('expired cache entry shows the loading placeholder', (
    tester,
  ) async {
    final manager = _FakeCacheManager();
    final bytes = await _validPngBytes(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: CachedProductImagePreview(
          imageUrl: 'https://example.com/stale.jpg',
          cacheManager: manager,
        ),
      ),
    );
    manager
        .completerFor('https://example.com/stale.jpg')
        .complete(
          _expiredInfo(_cachedFile(bytes), 'https://example.com/stale.jpg'),
        );
    await _pumpSettledFrames(tester);

    expect(find.byType(AppNetworkImageLoading), findsOneWidget);
    expect(manager.callCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cache manager error shows the loading placeholder, no thrown UI error',
    (tester) async {
      final manager = _FakeCacheManager();

      await tester.pumpWidget(
        MaterialApp(
          home: CachedProductImagePreview(
            imageUrl: 'https://example.com/error.jpg',
            cacheManager: manager,
          ),
        ),
      );
      manager
          .completerFor('https://example.com/error.jpg')
          .completeError(Exception('disk read failed'));
      await _pumpSettledFrames(tester);

      expect(find.byType(AppNetworkImageLoading), findsOneWidget);
      expect(manager.callCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('corrupted cached bytes fall back to the loading placeholder', (
    tester,
  ) async {
    final manager = _FakeCacheManager();

    await tester.pumpWidget(
      MaterialApp(
        home: CachedProductImagePreview(
          imageUrl: 'https://example.com/corrupt.jpg',
          cacheManager: manager,
        ),
      ),
    );
    manager
        .completerFor('https://example.com/corrupt.jpg')
        .complete(
          _validInfo(
            _cachedFile(Uint8List.fromList([1, 2, 3, 4, 5])),
            'https://example.com/corrupt.jpg',
          ),
        );
    await _pumpSettledFrames(tester, frames: 40);

    expect(find.byType(AppNetworkImageLoading), findsOneWidget);
    expect(
      tester
          .widgetList<RawImage>(find.byType(RawImage))
          .any((i) => i.image != null),
      isFalse,
    );
    expect(manager.callCount, 1);
  });

  testWidgets(
    'changing the url discards the old preview immediately and ignores stale in-flight completions',
    (tester) async {
      final manager = _FakeCacheManager();
      final bytesA = await _validPngBytes(tester);
      final bytesC = await _validPngBytes(tester);

      Widget appFor(String url) => MaterialApp(
        home: CachedProductImagePreview(imageUrl: url, cacheManager: manager),
      );

      await tester.pumpWidget(appFor('https://example.com/a.jpg'));
      manager
          .completerFor('https://example.com/a.jpg')
          .complete(_validInfo(_cachedFile(bytesA), 'https://example.com/a.jpg'));
      await _pumpUntilImageDecoded(tester);
      expect(
        tester
            .widgetList<RawImage>(find.byType(RawImage))
            .any((i) => i.image != null),
        isTrue,
      );

      // Switch to url B while A was showing: the old image must be discarded
      // immediately, before B's (still pending) cache lookup resolves.
      await tester.pumpWidget(appFor('https://example.com/b.jpg'));
      await _pumpSettledFrames(tester);
      expect(
        tester
            .widgetList<RawImage>(find.byType(RawImage))
            .any((i) => i.image != null),
        isFalse,
        reason: 'old image for url A must not flash while url B is loading',
      );
      expect(find.byType(AppNetworkImageLoading), findsOneWidget);

      // Switch again to url C before B's in-flight lookup resolves.
      await tester.pumpWidget(appFor('https://example.com/c.jpg'));
      await _pumpSettledFrames(tester);
      expect(
        tester
            .widgetList<RawImage>(find.byType(RawImage))
            .any((i) => i.image != null),
        isFalse,
      );

      // The stale url B completion must be ignored now that url C is current.
      manager
          .completerFor('https://example.com/b.jpg')
          .complete(_validInfo(_cachedFile(bytesA), 'https://example.com/b.jpg'));
      await _pumpSettledFrames(tester);
      expect(
        tester
            .widgetList<RawImage>(find.byType(RawImage))
            .any((i) => i.image != null),
        isFalse,
        reason: 'stale completion for a previous url must not render',
      );

      manager
          .completerFor('https://example.com/c.jpg')
          .complete(_validInfo(_cachedFile(bytesC), 'https://example.com/c.jpg'));
      await _pumpUntilImageDecoded(tester);
      expect(
        tester
            .widgetList<RawImage>(find.byType(RawImage))
            .any((i) => i.image != null),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'duplicate rebuild with the same url does not repeat the cache read',
    (tester) async {
      final manager = _FakeCacheManager();
      final bytes = await _validPngBytes(tester);

      Widget app() => MaterialApp(
        home: CachedProductImagePreview(
          imageUrl: 'https://example.com/a.jpg',
          cacheManager: manager,
        ),
      );

      await tester.pumpWidget(app());
      manager
          .completerFor('https://example.com/a.jpg')
          .complete(_validInfo(_cachedFile(bytes), 'https://example.com/a.jpg'));
      await _pumpUntilImageDecoded(tester);
      expect(manager.callCount, 1);

      await tester.pumpWidget(app());
      await _pumpSettledFrames(tester);

      expect(manager.callCount, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
