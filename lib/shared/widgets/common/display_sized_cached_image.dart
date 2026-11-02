import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';

/// Keep the shared disk cache while decoding enough pixels for the actual crop.
class DisplaySizedCachedImage extends CachedNetworkImageProvider {
  const DisplaySizedCachedImage(
    super.url, {
    super.cacheManager,
    required this.targetWidth,
    required this.targetHeight,
    required this.fit,
  });

  final int targetWidth;
  final int? targetHeight;
  final BoxFit fit;

  @override
  ImageStreamCompleter loadImage(
    CachedNetworkImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return super.loadImage(
      key,
      (buffer, {getTargetSize}) => decode(
        buffer,
        getTargetSize: (width, height) {
          final horizontal = targetWidth / width;
          final vertical = targetHeight == null
              ? horizontal
              : targetHeight! / height;
          final ratio = math.min(
            1.0,
            fit == BoxFit.cover
                ? math.max(horizontal, vertical)
                : math.min(horizontal, vertical),
          );
          return ui.TargetImageSize(
            width: (width * ratio).ceil(),
            height: (height * ratio).ceil(),
          );
        },
      ),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DisplaySizedCachedImage &&
      other.url == url &&
      other.targetWidth == targetWidth &&
      other.targetHeight == targetHeight &&
      other.fit == fit;

  @override
  int get hashCode => Object.hash(url, targetWidth, targetHeight, fit);
}
