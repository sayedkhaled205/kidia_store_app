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
	this.backgroundSize = 40,
    this.position = 'bottom_end',
  });

  final String iconVariant;
  final String iconStyle;
  final double iconSize;
  final Color? iconColor;
  final bool showBackground;
  final Color? backgroundColor;
  final double backgroundRadius;
  final double backgroundSize;
  final String position;
}
