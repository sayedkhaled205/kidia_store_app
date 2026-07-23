import 'package:flutter/material.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';

class ProductImageSwiper extends StatefulWidget {
  const ProductImageSwiper({
    required this.imageUrls,
    required this.semanticLabel,
    super.key,
    this.enabled = false,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.showIndicator = true,
  });

  final List<String> imageUrls;
  final String semanticLabel;
  final bool enabled;
  final BoxFit fit;
  final Alignment alignment;
  final bool showIndicator;

  @override
  State<ProductImageSwiper> createState() => _ProductImageSwiperState();
}

class _ProductImageSwiperState extends State<ProductImageSwiper> {
  int _page = 0;

  List<String> get _images => widget.imageUrls
      .map((String url) => url.trim())
      .where((String url) => url.isNotEmpty)
      .toSet()
      .toList(growable: false);

  @override
  void didUpdateWidget(covariant ProductImageSwiper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_page >= _images.length) {
      _page = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> images = _images;
    if (images.isEmpty) {
      return const AppNetworkImageError();
    }
    if (!widget.enabled || images.length < 2) {
      return AppNetworkImage(
        imageUrl: images.first,
        fit: widget.fit,
        alignment: widget.alignment,
        semanticLabel: widget.semanticLabel,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PageView.builder(
          key: ValueKey<String>(
            'product-image-swiper-${images.join('|').hashCode}',
          ),
          itemCount: images.length,
          onPageChanged: (int page) => setState(() => _page = page),
          itemBuilder: (BuildContext context, int index) => AppNetworkImage(
            imageUrl: images[index],
            fit: widget.fit,
            alignment: widget.alignment,
            semanticLabel: '${widget.semanticLabel} ${index + 1}',
          ),
        ),
        if (widget.showIndicator)
          PositionedDirectional(
            start: 8,
            end: 8,
            bottom: 7,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(
                images.length.clamp(0, 6).toInt(),
                (int index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: index == _page ? 13 : 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: index == _page
                        ? Colors.white
                        : Colors.white.withValues(alpha: .56),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(color: Colors.black26, blurRadius: 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
