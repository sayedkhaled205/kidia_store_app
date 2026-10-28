import 'package:flutter/material.dart';

import '../../../core/app_design/app_ui_controls.dart';

/// Optional sizes inherit each platform's current design when cleared.
class CheckoutAppearance {
  CheckoutAppearance.of(BuildContext context)
    : values = AppUiControlsScope.of(context).values,
      buttonText = Theme.of(context).textTheme.labelLarge;
  final Map<String, dynamic> values;
  final TextStyle? buttonText;

  double? optional(String key) => (values['checkout_$key'] as num?)?.toDouble();
  double number(String key, double fallback) => optional(key) ?? fallback;

  InputDecorationThemeData fields(InputDecorationThemeData base) {
    final radius = optional('field_radius');
    final padding = optional('field_padding');
    InputBorder? border(InputBorder? existing) =>
        radius != null && existing is OutlineInputBorder
        ? existing.copyWith(borderRadius: BorderRadius.circular(radius))
        : existing;
    return base.copyWith(
      contentPadding: padding == null
          ? base.contentPadding
          : EdgeInsets.symmetric(horizontal: 16, vertical: padding),
      border: border(base.border),
      enabledBorder: border(base.enabledBorder),
      disabledBorder: border(base.disabledBorder),
      focusedBorder: border(base.focusedBorder),
      errorBorder: border(base.errorBorder),
      focusedErrorBorder: border(base.focusedErrorBorder),
    );
  }

  ButtonStyle? buttonStyle() {
    final height = optional('button_height');
    final radius = optional('button_radius');
    final font = optional('button_font_size');
    if (height == null && radius == null && font == null) return null;
    return FilledButton.styleFrom(
      minimumSize: height == null ? null : Size(64, height),
      textStyle: font == null ? null : buttonText?.copyWith(fontSize: font),
      shape: radius == null
          ? null
          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    );
  }
}
