import 'dart:async';
import 'dart:ui' as ui;

import 'package:file/file.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/shared/widgets/common/display_sized_cached_image.dart';

class _ImageFile implements File {
  _ImageFile(this.bytes);
  final Uint8List bytes;
  @override
  Future<Uint8List> readAsBytes() async => bytes;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ImageCache implements BaseCacheManager {
  _ImageCache(this.file);
  final File file;
  @override
  Stream<FileResponse> getFileStream(
    String url, {
    String? key,
    Map<String, String>? headers,
    bool withProgress = false,
  }) async* {
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

void main() {
  for (final target in [const Size(80, 80), const Size(80, 120)]) {
    testWidgets(
      'landscape image keeps enough pixels for cover $target at DPR3',
      (tester) async {
        final recorder = ui.PictureRecorder();
        Canvas(recorder).drawColor(Colors.red, BlendMode.src);
        final picture = recorder.endRecording();
        final bytes = (await tester.runAsync(() async {
          final source = await picture.toImage(1600, 800);
          final data = (await source.toByteData(
            format: ui.ImageByteFormat.png,
          ))!.buffer.asUint8List();
          source.dispose();
          return data;
        }))!;
        picture.dispose();
        addTearDown(() => PaintingBinding.instance.imageCache.clear());
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(devicePixelRatio: 3),
              child: Center(
                child: Image(
                  image: DisplaySizedCachedImage(
                    'https://example.com/${target.height}.png',
                    cacheManager: _ImageCache(_ImageFile(bytes)),
                    targetWidth: (target.width * 3).ceil(),
                    targetHeight: (target.height * 3).ceil(),
                    fit: BoxFit.cover,
                  ),
                  width: target.width,
                  height: target.height,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        );
        for (var attempt = 0; attempt < 100; attempt++) {
          if (tester
              .widgetList<RawImage>(find.byType(RawImage))
              .any((image) => image.image != null)) {
            break;
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        final raw = tester
            .widgetList<RawImage>(find.byType(RawImage))
            .where((image) => image.image != null)
            .single
            .image!;
        expect(raw.width, (target.height * 6).ceil());
        expect(raw.height, (target.height * 3).ceil());
        expect(raw.width * raw.height, lessThan(1600 * 800));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
