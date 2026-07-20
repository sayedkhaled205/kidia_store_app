import 'package:flutter/material.dart';

class ProductWishlistAppearance {
  const ProductWishlistAppearance({
    this.enabled = false,
    this.iconVariant = 'heart',
    this.iconStyle = 'outline',
    this.iconSize = 20,
    this.iconColor,
    this.showBackground = true,
    this.backgroundColor,
    this.backgroundSize = 40,
    this.backgroundRadius = 24,
    this.position = 'top_end',
  });

  final bool enabled;
  final String iconVariant;
  final String iconStyle;
  final double iconSize;
  final Color? iconColor;
  final bool showBackground;
  final Color? backgroundColor;
  final double backgroundSize;
  final double backgroundRadius;
  final String position;
}
