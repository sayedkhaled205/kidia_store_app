import 'package:flutter/material.dart';

import 'mobishop_colors.dart';
import 'mobishop_radius.dart';
import 'mobishop_spacing.dart';
import 'mobishop_typography.dart';

abstract final class MobiShopTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: MobiShopColors.primary,
      brightness: Brightness.light,
      primary: MobiShopColors.primary,
      secondary: MobiShopColors.secondary,
      surface: MobiShopColors.surface,
      error: MobiShopColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: MobiShopColors.background,
      textTheme: const TextTheme(
        displayLarge: MobiShopTypography.displayLarge,
        headlineLarge: MobiShopTypography.headlineLarge,
        headlineMedium: MobiShopTypography.headlineMedium,
        titleLarge: MobiShopTypography.titleLarge,
        titleMedium: MobiShopTypography.titleMedium,
        bodyLarge: MobiShopTypography.bodyLarge,
        bodyMedium: MobiShopTypography.bodyMedium,
        bodySmall: MobiShopTypography.bodySmall,
        labelLarge: MobiShopTypography.labelLarge,
        labelMedium: MobiShopTypography.labelMedium,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: MobiShopColors.surface,
        foregroundColor: MobiShopColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: MobiShopTypography.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: MobiShopColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MobiShopRadius.lg),
          side: const BorderSide(color: MobiShopColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MobiShopColors.surface,
        hintStyle: MobiShopTypography.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MobiShopSpacing.md,
          vertical: MobiShopSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MobiShopRadius.md),
          borderSide: const BorderSide(color: MobiShopColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MobiShopRadius.md),
          borderSide: const BorderSide(color: MobiShopColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(MobiShopRadius.md),
          borderSide: const BorderSide(color: MobiShopColors.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          backgroundColor: MobiShopColors.primary,
          foregroundColor: Colors.white,
          textStyle: MobiShopTypography.labelLarge.copyWith(color: Colors.white),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MobiShopRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          foregroundColor: MobiShopColors.primary,
          textStyle: MobiShopTypography.labelLarge.copyWith(
            color: MobiShopColors.primary,
          ),
          side: const BorderSide(color: MobiShopColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MobiShopRadius.md),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: MobiShopColors.divider,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: MobiShopColors.surface,
        indicatorColor: MobiShopColors.primaryLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return selected
              ? MobiShopTypography.labelMedium.copyWith(
                  color: MobiShopColors.primaryDark,
                  fontWeight: FontWeight.w700,
                )
              : MobiShopTypography.labelMedium;
        }),
      ),
    );
  }
}
