import 'package:flutter/material.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';

class AppImageBanner extends StatelessWidget {
  const AppImageBanner({
    required this.imageUrl,
    super.key,
    this.onTap,
    this.semanticLabel,
    this.aspectRatio = 2.4,
    this.borderRadius = 20,
    this.backgroundColor,
    this.contentPadding = EdgeInsets.zero,
  });

  final String imageUrl;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double aspectRatio;
  final double borderRadius;
  final Color? backgroundColor;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      button: onTap != null,
      label: semanticLabel,
      child: Material(
        color: backgroundColor ??
            colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: contentPadding,
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: AppNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                semanticLabel: semanticLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}