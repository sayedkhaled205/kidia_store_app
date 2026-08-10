import 'package:flutter/material.dart';

import 'mobishop_colors.dart';

abstract final class MobiShopTypography {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 32,
    height: 1.25,
    fontWeight: FontWeight.w800,
    color: MobiShopColors.textPrimary,
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 26,
    height: 1.3,
    fontWeight: FontWeight.w800,
    color: MobiShopColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 22,
    height: 1.35,
    fontWeight: FontWeight.w700,
    color: MobiShopColors.textPrimary,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 18,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: MobiShopColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w600,
    color: MobiShopColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: MobiShopColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: MobiShopColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    height: 1.5,
    fontWeight: FontWeight.w400,
    color: MobiShopColors.textSecondary,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: MobiShopColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w600,
    color: MobiShopColors.textSecondary,
  );
}
