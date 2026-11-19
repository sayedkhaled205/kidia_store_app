import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'app_network_image.dart';

/// Placeholder shown in [AppNetworkImage.placeholder] while the original
/// product photo downloads. Reads only from the existing disk cache (no
/// network access). A cache miss keeps the normal loading placeholder.
class CachedProductImagePreview extends StatefulWidget {
  const CachedProductImagePreview({
    required this.imageUrl,
    super.key,
    this.fit = BoxFit.contain,
    this.backgroundColor,
    this.cacheManager,
  });

  final String imageUrl;
  final BoxFit fit;
  final Color? backgroundColor;
  final BaseCacheManager? cacheManager;

  @override
  State<CachedProductImagePreview> createState() =>
      _CachedProductImagePreviewState();
}

class _CachedProductImagePreviewState extends State<CachedProductImagePreview> {
  FileInfo? _info;
  int _generation = 0;

  BaseCacheManager get _cacheManager =>
      widget.cacheManager ?? CachedNetworkImageProvider.defaultCacheManager;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _load();
  }

  @override
  void didUpdateWidget(covariant CachedProductImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (kIsWeb) return;
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.cacheManager != widget.cacheManager) {
      // Discard the previous preview immediately so a stale completion from
      // the prior URL can never flash over the new one.
      _info = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final url = widget.imageUrl.trim();
    if (url.isEmpty) return;

    FileInfo? info;
    try {
      info = await _cacheManager.getFileFromCache(url);
    } catch (_) {
      return;
    }
    if (!mounted || generation != _generation) return;
    if (info == null || !info.validTill.isAfter(DateTime.now())) return;
    setState(() => _info = info);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return AppNetworkImageLoading(backgroundColor: widget.backgroundColor);
    }

    final info = _info;
    if (info == null) {
      return AppNetworkImageLoading(backgroundColor: widget.backgroundColor);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : null;
        final cacheWidth = width != null && width.isFinite && width > 0
            ? (width * MediaQuery.devicePixelRatioOf(context)).ceil()
            : null;
        return Image.file(
          info.file,
          cacheWidth: cacheWidth,
          fit: widget.fit,
          excludeFromSemantics: true,
          frameBuilder: (context, child, frame, synchronous) => frame != null
              ? child
              : AppNetworkImageLoading(backgroundColor: widget.backgroundColor),
          errorBuilder: (context, error, stack) =>
              AppNetworkImageLoading(backgroundColor: widget.backgroundColor),
        );
      },
    );
  }
}
