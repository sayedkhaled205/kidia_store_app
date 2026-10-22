import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/shared/widgets/common/wordmark_image.dart';

void main() {
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
}
