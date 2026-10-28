import 'package:flutter/material.dart';

import '../app_design/app_ui_controls.dart';

/// Presentation-only overrides; existing message content and actions stay intact.
ThemeData publishedMessageTheme(ThemeData base, AppUiControls controls) {
  if (!controls.values.keys.any((key) => key.startsWith('message_'))) {
    return base;
  }
  final previous = base.snackBarTheme;
  final style = controls.values['message_style'] ?? 'theme';
  final background = switch (style) {
    'soft' => Color.alphaBlend(
      base.colorScheme.primary.withValues(alpha: .10),
      base.colorScheme.surface,
    ),
    'brand' => base.colorScheme.primary,
    _ => previous.backgroundColor ?? base.colorScheme.inverseSurface,
  };
  final foreground = background.computeLuminance() > .179
      ? Colors.black
      : Colors.white;
  final radius = controls.values['message_radius'] as num?;
  final inset = controls.values['message_inset'] as num?;
  final fontSize = controls.values['message_font_size'] as num?;
  return base.copyWith(
    snackBarTheme: previous.copyWith(
      backgroundColor: background,
      contentTextStyle: (previous.contentTextStyle ?? base.textTheme.bodyMedium)
          ?.copyWith(color: foreground, fontSize: fontSize?.toDouble()),
      actionTextColor: foreground,
      disabledActionTextColor: foreground.withValues(alpha: .6),
      closeIconColor: foreground,
      behavior: radius != null || inset != null
          ? SnackBarBehavior.floating
          : previous.behavior,
      shape: radius == null
          ? previous.shape
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius.toDouble()),
            ),
      insetPadding: inset == null
          ? previous.insetPadding
          : EdgeInsets.all(inset.toDouble()),
    ),
  );
}
