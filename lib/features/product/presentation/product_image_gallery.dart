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
  bool _canPageFromImage = false;
  Offset _imageDrag = Offset.zero;
  int _dragPage = 0;

  void _startImageGesture(ScaleStartDetails details) {
    _canPageFromImage = !_zoomed && !_pinching && details.pointerCount == 1;
    _imageDrag = Offset.zero;
    _dragPage = _index;
    if (details.pointerCount > 1) setState(() => _pinching = true);
  }

  void _updateImageGesture(ScaleUpdateDetails details) {
    if (details.pointerCount > 1 || _zoomed) _canPageFromImage = false;
    if (_canPageFromImage) _imageDrag += details.focalPointDelta;
  }

  void _endImageGesture(ScaleEndDetails details) {
    // Scale can win a coarse single-finger move on Android even when pan is
    // disabled. Complete that swipe here; PageView handles gestures it wins.
    final distance = _imageDrag.dx.abs();
    final velocity = details.velocity.pixelsPerSecond.dx;
    final width = _pages.hasClients ? _pages.position.viewportDimension : 0.0;
    final shouldPage =
        details.pointerCount == 0 &&
        _canPageFromImage &&
        !_zoomed &&
        !_pinching &&
        _dragPage == _index &&
        width > 0 &&
        distance > _imageDrag.dy.abs() &&
        (distance >= width * .35 || (distance >= 24 && velocity.abs() >= 500));
    _canPageFromImage = false;
    if (details.pointerCount == 0 && _pinching) {
      setState(() => _pinching = false);
    }
    if (!shouldPage) return;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final forward = rtl ? _imageDrag.dx > 0 : _imageDrag.dx < 0;
    final next = (_index + (forward ? 1 : -1)).clamp(
      0,
      widget.images.length - 1,
    );
    if (next != _index) {
      _pages.animateToPage(
        next,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

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
                  onInteractionStart: _startImageGesture,
                  onInteractionUpdate: _updateImageGesture,
                  onInteractionEnd: _endImageGesture,
                  child: content,
                );
              },
            ),
    ),
  );
}
