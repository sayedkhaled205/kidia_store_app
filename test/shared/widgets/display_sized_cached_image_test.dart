import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file/file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/shared/widgets/common/app_network_image.dart';

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
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => '.',
        );
        final oldCache = CachedNetworkImageProvider.defaultCacheManager;
        CachedNetworkImageProvider.defaultCacheManager = _ImageCache(
          _ImageFile(bytes),
        );
        addTearDown(() {
          CachedNetworkImageProvider.defaultCacheManager = oldCache;
          PaintingBinding.instance.imageCache.clear();
        });
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(devicePixelRatio: 3),
              child: Center(
                child: AppNetworkImage(
                  imageUrl: 'https://example.com/${target.height}.png',
                  width: target.width,
                  height: target.height,
                  decodeAtDisplaySize: true,
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pump();
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
