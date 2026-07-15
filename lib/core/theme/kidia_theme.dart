import 'package:flutter/material.dart';

import 'kidia_colors.dart';
import 'kidia_radius.dart';
import 'kidia_spacing.dart';
import 'kidia_typography.dart';

abstract final class KidiaTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: KidiaColors.primary,
      brightness: Brightness.light,
      primary: KidiaColors.primary,
      secondary: KidiaColors.secondary,
      surface: KidiaColors.surface,
      error: KidiaColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: KidiaColors.background,
      textTheme: const TextTheme(
        displayLarge: KidiaTypography.displayLarge,
        headlineLarge: KidiaTypography.headlineLarge,
        headlineMedium: KidiaTypography.headlineMedium,
        titleLarge: KidiaTypography.titleLarge,
        titleMedium: KidiaTypography.titleMedium,
        bodyLarge: KidiaTypography.bodyLarge,
        bodyMedium: KidiaTypography.bodyMedium,
        bodySmall: KidiaTypography.bodySmall,
        labelLarge: KidiaTypography.labelLarge,
        labelMedium: KidiaTypography.labelMedium,
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: KidiaColors.surface,
        foregroundColor: KidiaColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: KidiaTypography.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: KidiaColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(KidiaRadius.lg),
          side: const BorderSide(
            color: KidiaColors.border,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KidiaColors.surface,
        hintStyle: KidiaTypography.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: KidiaSpacing.md,
          vertical: KidiaSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KidiaRadius.md),
          borderSide: const BorderSide(
            color: KidiaColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KidiaRadius.md),
          borderSide: const BorderSide(
            color: KidiaColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KidiaRadius.md),
          borderSide: const BorderSide(
            color: KidiaColors.primary,
            width: 1.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: KidiaColors.primary,
          foregroundColor: Colors.white,
          textStyle: KidiaTypography.labelLarge.copyWith(
            color: Colors.white,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KidiaRadius.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: KidiaColors.primary,
          textStyle: KidiaTypography.labelLarge.copyWith(
            color: KidiaColors.primary,
          ),
          side: const BorderSide(
            color: KidiaColors.primary,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KidiaRadius.md),
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: KidiaColors.divider,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: KidiaColors.surface,
        indicatorColor: KidiaColors.primaryLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);

          return selected
              ? KidiaTypography.labelMedium.copyWith(
            color: KidiaColors.primaryDark,
            fontWeight: FontWeight.w700,
          )
              : KidiaTypography.labelMedium;
        }),
      ),
    );
  }
}