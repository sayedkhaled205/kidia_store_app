import 'package:flutter/material.dart';

class ProductQuickAddAppearance {
  const ProductQuickAddAppearance({
    this.iconVariant = 'bag',
    this.iconStyle = 'outline',
    this.iconSize = 22,
    this.iconColor,
    this.showBackground = true,
    this.backgroundColor,
    this.backgroundRadius = 24,
  });

  final String iconVariant;
  final String iconStyle;
  final double iconSize;
  final Color? iconColor;
  final bool showBackground;
  final Color? backgroundColor;
  final double backgroundRadius;
}
