import 'package:flutter/material.dart';
import 'builder_font_family.dart';

/// Apply the current builder identity without changing phone layout metrics.
ThemeData previewIdentityTheme(ThemeData base, Map<String, dynamic>? identity) {
  return _identityTheme(base, identity, TargetPlatform.android);
}

/// Native branding shares builder colors/fonts, but retains iOS/Android metrics.
ThemeData applicationIdentityTheme(
  ThemeData base,
  Map<String, dynamic>? identity,
) => _identityTheme(base, identity, base.platform);

ThemeData _identityTheme(
  ThemeData base,
  Map<String, dynamic>? identity,
  TargetPlatform platform,
) {
  Color? color(String key) {
    final value = '${identity?[key] ?? ''}';
    if (!RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) return null;
    return Color(0xff000000 | int.parse(value.substring(1), radix: 16));
  }

  final primary = color('primary_color') ?? base.colorScheme.primary;
  final secondary = color('secondary_color') ?? base.colorScheme.secondary;
  final font = builderFontFamily('${identity?['font_family'] ?? 'system'}');
  TextStyle? style(TextStyle? value) => font == null
      ? value
      : value?.copyWith(
          fontFamily: font,
          fontFamilyFallback: const ['Noto Sans Arabic'],
        );
  return base.copyWith(
    platform: platform,
    colorScheme: base.colorScheme.copyWith(
      primary: primary,
      secondary: secondary,
    ),
    textTheme: font == null
        ? base.textTheme
        : base.textTheme.apply(
            fontFamily: font,
            fontFamilyFallback: const ['Noto Sans Arabic'],
          ),
    primaryTextTheme: font == null
        ? base.primaryTextTheme
        : base.primaryTextTheme.apply(
            fontFamily: font,
            fontFamilyFallback: const ['Noto Sans Arabic'],
          ),
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: style(base.appBarTheme.titleTextStyle),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: base.filledButtonTheme.style?.copyWith(
        textStyle: WidgetStateProperty.resolveWith(
          (states) =>
              style(base.filledButtonTheme.style?.textStyle?.resolve(states)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? base.filledButtonTheme.style?.backgroundColor?.resolve(states)
              : primary,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: base.outlinedButtonTheme.style?.copyWith(
        textStyle: WidgetStateProperty.resolveWith(
          (states) =>
              style(base.outlinedButtonTheme.style?.textStyle?.resolve(states)),
        ),
        foregroundColor: WidgetStatePropertyAll(primary),
        side: WidgetStatePropertyAll(BorderSide(color: primary)),
      ),
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      hintStyle: style(base.inputDecorationTheme.hintStyle),
      focusedBorder: base.inputDecorationTheme.focusedBorder?.copyWith(
        borderSide: BorderSide(color: primary, width: 1.5),
      ),
    ),
  );
}
