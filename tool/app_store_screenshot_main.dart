// Simulator-only listing capture. The shipping entry point remains lib/main.dart.
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mobishop_store_app/app/app.dart';
import 'package:mobishop_store_app/app/app_router.dart';
import 'package:mobishop_store_app/core/localization/app_locale_provider.dart';

Future<void> main() async {
  if (!kDebugMode || defaultTargetPlatform != TargetPlatform.iOS) {
    throw UnsupportedError('Listing capture requires an iOS debug simulator.');
  }
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final documents = await getApplicationDocumentsDirectory();
  final readiness = File('${documents.path}/app-store-capture-ready-v1.txt');
  if (await readiness.exists()) await readiness.delete();
  final container = ProviderContainer();
  await container.read(appLanguagePreferenceProvider.future);
  await container
      .read(appLanguagePreferenceProvider.notifier)
      .select(AppLanguage.ar);
  final view = binding.platformDispatcher.views.first;
  final width = view.physicalSize.width / view.devicePixelRatio;
  final router = createAppRouter(
    initialLocation: width >= 600 ? '/categories' : '/',
  );
  // Use the actual screens, saved design and live catalog. Push enrollment is
  // intentionally not started in this capture entry point, so its first-run
  // system prompt cannot obscure the listing image. No product data is mocked.
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MobiShopApp(router: router),
    ),
  );
  var stableChecks = 0;
  var attempts = 0;
  Timer.periodic(const Duration(seconds: 2), (timer) async {
    var images = 0;
    var paragraphs = 0;
    final viewport = Offset.zero & (view.physicalSize / view.devicePixelRatio);
    void inspect(RenderObject object) {
      if (object is RenderOffstage && object.offstage) return;
      if (object is RenderBox && object.hasSize && object.attached) {
        final rect = object.localToGlobal(Offset.zero) & object.size;
        if (!rect.overlaps(viewport)) return;
        if (object is RenderImage && object.image != null) images++;
        if (object is RenderParagraph &&
            object.text.toPlainText().trim().isNotEmpty) {
          paragraphs++;
        }
      }
      object.visitChildren(inspect);
    }

    for (final renderView in binding.renderViews) {
      inspect(renderView);
    }
    stableChecks = images >= 3 && paragraphs >= 4 ? stableChecks + 1 : 0;
    if (stableChecks >= 2) {
      timer.cancel();
      // A local simulator artifact, independent of Flutter's debug log transport.
      // Publish only after the real visible content passed consecutive checks.
      final staged = File('${readiness.path}.tmp');
      await staged.writeAsString(
        'APP_STORE_CAPTURE_READY_V1 images=$images text=$paragraphs',
        flush: true,
      );
      await staged.rename(readiness.path);
    } else if (++attempts >= 60) {
      debugPrintSynchronously(
        'APP_STORE_CAPTURE_NOT_READY images=$images text=$paragraphs',
      );
      timer.cancel();
    }
  });
}
