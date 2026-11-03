import 'package:flutter/material.dart';
import '../../catalog/domain/entities/catalog_image.dart';
import '../../../shared/widgets/common/app_network_image.dart';

/// The original image is loaded on demand so zoom retains product detail.
class ProductImageGallery extends StatefulWidget {
  const ProductImageGallery({
    required this.images,
    required this.productName,
    this.initialIndex = 0,
    super.key,
  });

  final List<CatalogImage> images;
  final String productName;
  final int initialIndex;

  @override
  State<ProductImageGallery> createState() => _ProductImageGalleryState();
}

class _ProductImageGalleryState extends State<ProductImageGallery> {
  late int _index;
  late final PageController _pages;
  final _transform = TransformationController();
  bool _zoomed = false;
  bool _pinching = false;

  @override
  void initState() {
    super.initState();
    _index = widget.images.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.images.length - 1);
    _pages = PageController(initialPage: _index);
    _transform.addListener(_updateZoom);
  }

  void _updateZoom() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    if (_zoomed != zoomed) setState(() => _zoomed = zoomed);
  }

  @override
  void dispose() {
    _transform.removeListener(_updateZoom);
    _transform.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('product-fullscreen-gallery'),
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      leading: const BackButton(key: Key('product-gallery-back')),
      title: Text(
        widget.images.isEmpty
            ? '0 / 0'
            : '${_index + 1} / ${widget.images.length}',
        key: const Key('fullscreen-gallery-counter'),
        textDirection: TextDirection.ltr,
      ),
    ),
    body: SafeArea(
      top: false,
      child: widget.images.isEmpty
          ? const Center(child: AppNetworkImageError())
          : PageView.builder(
              key: const Key('fullscreen-gallery-pages'),
              controller: _pages,
              itemCount: widget.images.length,
              physics: _zoomed || _pinching
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              onPageChanged: (index) {
                _transform.value = Matrix4.identity();
                setState(() {
                  _index = index;
                  _pinching = false;
                });
              },
              itemBuilder: (context, index) {
                final image = widget.images[index];
                final content = AppNetworkImage(
                  key: Key('fullscreen-product-image-$index'),
                  imageUrl: image.source.toString(),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  backgroundColor: Colors.white,
                  semanticLabel: image.alt.isEmpty
                      ? widget.productName
                      : image.alt,
                );
                if (index != _index) return content;
                return InteractiveViewer(
                  key: const Key('fullscreen-image-zoom'),
                  transformationController: _transform,
                  minScale: 1,
                  maxScale: 5,
                  panEnabled: _zoomed,
                  onInteractionStart: (details) {
                    if (details.pointerCount > 1) {
                      setState(() => _pinching = true);
                    }
                  },
                  onInteractionEnd: (_) {
                    if (_pinching) setState(() => _pinching = false);
                  },
                  child: content,
                );
              },
            ),
    ),
  );
}
