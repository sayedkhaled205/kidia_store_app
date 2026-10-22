import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Trim transparent or uniform light export padding around brand artwork.
Rect visibleWordmarkBounds(Uint8List rgba, int width, int height) {
  bool canvas(int x, int y) {
    final i = (y * width + x) * 4;
    return rgba[i + 3] > 245 &&
        (rgba[i] - rgba[0]).abs() < 8 &&
        (rgba[i + 1] - rgba[1]).abs() < 8 &&
        (rgba[i + 2] - rgba[2]).abs() < 8;
  }

  // Trim only a uniform light, neutral export canvas, never brand colors.
  final whiteCanvas =
      rgba[0] > 220 &&
      rgba[1] > 220 &&
      rgba[2] > 220 &&
      canvas(0, 0) &&
      canvas(width - 1, 0) &&
      canvas(0, height - 1) &&
      canvas(width - 1, height - 1);
  var left = width, top = height, right = -1, bottom = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      if (rgba[(y * width + x) * 4 + 3] > 12 &&
          !(whiteCanvas && canvas(x, y))) {
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
  }
  return right < left
      ? Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble())
      : Rect.fromLTRB(
          left.toDouble(),
          top.toDouble(),
          (right + 1).toDouble(),
          (bottom + 1).toDouble(),
        );
}

/// Optional geometry travels with the logo URL across saved builder designs.
double wordmarkAspectRatio(String url) {
  final fragment = Uri.tryParse(url)?.fragment ?? '';
  if (!fragment.startsWith('wm=')) return 0;
  final parts = fragment.substring(3).split(',');
  if (parts.length != 5) return 0;
  final coordinates = parts
      .map((part) => double.tryParse(part) ?? double.nan)
      .toList();
  if (!coordinates.every((value) => value.isFinite) ||
      coordinates[0] < 0 ||
      coordinates[1] < 0 ||
      coordinates[2] <= 0 ||
      coordinates[3] <= 0 ||
      coordinates[0] + coordinates[2] > 1.001 ||
      coordinates[1] + coordinates[3] > 1.001) {
    return 0;
  }
  final ratio = coordinates.last;
  return ratio.isFinite && ratio > 0 && ratio <= 10 ? ratio : 0;
}

/// Keep preview geometry proportional without reading cross-origin image pixels.
class WebWordmarkImage extends StatelessWidget {
  const WebWordmarkImage({
    required this.url,
    required this.width,
    required this.height,
    required this.fallback,
    super.key,
  });
  final String url;
  final double width, height;
  final Widget fallback;
  @override
  Widget build(BuildContext context) {
    final crop = Uri.parse(
      url,
    ).fragment.substring(3).split(',').map(double.parse).toList();
    final size = applyBoxFit(
      BoxFit.contain,
      Size(crop[4], 1),
      Size(width, height),
    ).destination;
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: ClipRect(
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: Stack(
              children: [
                Positioned(
                  left: -crop[0] * size.width / crop[2],
                  top: -crop[1] * size.height / crop[3],
                  width: size.width / crop[2],
                  height: size.height / crop[3],
                  child: Image.network(
                    url,
                    fit: BoxFit.fill,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    errorBuilder: (context, error, stack) => fallback,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WordmarkImage extends StatefulWidget {
  const WordmarkImage({
    required this.url,
    required this.width,
    required this.height,
    required this.fallback,
    this.contentAspectRatio = 0,
    super.key,
  });
  final String url;
  final double width, height;
  final double contentAspectRatio;
  final Widget fallback;
  @override
  State<WordmarkImage> createState() => _WordmarkImageState();
}

class _WordmarkImageState extends State<WordmarkImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  ui.Image? _image;
  Rect? _bounds;
  bool _failed = false;
  int _generation = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(WordmarkImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _resolve();
  }

  void _resolve() {
    _stream?.removeListener(_listener!);
    final generation = ++_generation;
    _failed = false;
    _image?.dispose();
    _image = null;
    _bounds = null;
    _stream = CachedNetworkImageProvider(
      widget.url,
    ).resolve(createLocalImageConfiguration(context));
    _listener = ImageStreamListener(
      (info, _) async {
        final image = info.image.clone();
        info.dispose();
        Rect bounds = Rect.fromLTWH(
          0,
          0,
          image.width.toDouble(),
          image.height.toDouble(),
        );
        try {
          if (image.width * image.height <= 4000000) {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            );
            if (bytes != null) {
              bounds = visibleWordmarkBounds(
                bytes.buffer.asUint8List(
                  bytes.offsetInBytes,
                  bytes.lengthInBytes,
                ),
                image.width,
                image.height,
              );
            }
          }
        } catch (_) {
          /* Opaque images still render with their original proportions. */
        }
        if (!mounted || generation != _generation) {
          image.dispose();
          return;
        }
        setState(() {
          _image?.dispose();
          _image = image;
          _bounds = bounds;
        });
      },
      onError: (Object error, StackTrace? stack) {
        if (mounted && generation == _generation) {
          setState(() => _failed = true);
        }
      },
    );
    _stream!.addListener(_listener!);
  }

  @override
  void dispose() {
    _generation++;
    _stream?.removeListener(_listener!);
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: _failed
        ? widget.fallback
        : _image == null
        ? const SizedBox.shrink()
        : CustomPaint(
            painter: _WordmarkPainter(
              _image!,
              _bounds!,
              widget.contentAspectRatio > 0
                  ? widget.contentAspectRatio
                  : wordmarkAspectRatio(widget.url),
            ),
          ),
  );
}

class _WordmarkPainter extends CustomPainter {
  _WordmarkPainter(this.image, this.bounds, this.contentAspectRatio);
  final double contentAspectRatio;
  final ui.Image image;
  final Rect bounds;
  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(
      BoxFit.contain,
      contentAspectRatio > 0 ? Size(contentAspectRatio, 1) : bounds.size,
      size,
    );
    canvas.drawImageRect(
      image,
      bounds,
      Alignment.center.inscribe(fitted.destination, Offset.zero & size),
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(_WordmarkPainter old) =>
      old.image != image ||
      old.bounds != bounds ||
      old.contentAspectRatio != contentAspectRatio;
}
