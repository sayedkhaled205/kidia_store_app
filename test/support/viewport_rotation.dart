import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void viewportRotationTests(
  String screen,
  Future<void> Function(WidgetTester, Size) pump,
) {
  for (final size in [
    const Size(390, 844),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1024, 768),
  ]) {
    testWidgets('$screen viewport rotation $size', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final originalError = FlutterError.onError;
      FlutterError.onError = (details) {
        debugPrint(details.toString());
        originalError!(details);
      };
      addTearDown(() => FlutterError.onError = originalError);
      await pump(tester, size);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final viewport in [size, Size(size.height, size.width), size]) {
        tester.view.physicalSize = viewport;
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Exercise lazy content and bottom actions, not just the first frame.
        final scrollables = tester
            .stateList<ScrollableState>(find.byType(Scrollable))
            .toList();
        for (final scrollable in scrollables) {
          if (!scrollable.mounted || !scrollable.position.hasContentDimensions) {
            continue;
          }
          final position = scrollable.position;
          if (position.maxScrollExtent.isFinite) {
            position.jumpTo(position.maxScrollExtent);
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (scrollable.mounted) position.jumpTo(position.minScrollExtent);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}

