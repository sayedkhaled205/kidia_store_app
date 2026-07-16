import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    required this.imageUrl,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.borderRadius,
    this.backgroundColor,
    this.semanticLabel,
    this.placeholder,
    this.errorWidget,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final String? semanticLabel;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  Widget build(BuildContext context) {
    final Widget image = Semantics(
      image: true,
      label: semanticLabel,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        fadeInDuration: const Duration(milliseconds: 220),
        fadeOutDuration: const Duration(milliseconds: 120),
        placeholderFadeInDuration: const Duration(milliseconds: 120),
        placeholder: (
            BuildContext context,
            String url,
            ) {
          return placeholder ??
              AppNetworkImageLoading(
                width: width,
                height: height,
                backgroundColor: backgroundColor,
              );
        },
        errorWidget: (
            BuildContext context,
            String url,
            Object error,
            ) {
          return errorWidget ??
              AppNetworkImageError(
                width: width,
                height: height,
                backgroundColor: backgroundColor,
              );
        },
      ),
    );

    if (borderRadius == null) {
      return image;
    }

    return ClipRRect(
      borderRadius: borderRadius!,
      child: image,
    );
  }
}

class AppNetworkImageLoading extends StatefulWidget {
  const AppNetworkImageLoading({
    super.key,
    this.width,
    this.height,
    this.backgroundColor,
  });

  final double? width;
  final double? height;
  final Color? backgroundColor;

  @override
  State<AppNetworkImageLoading> createState() {
    return _AppNetworkImageLoadingState();
  }
}

class _AppNetworkImageLoadingState extends State<AppNetworkImageLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final Color baseColor = widget.backgroundColor ??
        colorScheme.surfaceContainerHighest;

    final Color highlightColor = colorScheme.surfaceContainerLow;

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (
            BuildContext context,
            Widget? child,
            ) {
          return ColoredBox(
            color: Color.lerp(
              baseColor,
              highlightColor,
              _animation.value,
            )!,
            child: child,
          );
        },
        child: Center(
          child: Icon(
            Icons.image_outlined,
            size: 28,
            color: colorScheme.onSurfaceVariant.withValues(
              alpha: 0.45,
            ),
          ),
        ),
      ),
    );
  }
}

class AppNetworkImageError extends StatelessWidget {
  const AppNetworkImageError({
    super.key,
    this.width,
    this.height,
    this.backgroundColor,
    this.iconSize = 30,
  });

  final double? width;
  final double? height;
  final Color? backgroundColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: width,
      height: height,
      child: ColoredBox(
        color: backgroundColor ??
            colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: iconSize,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
