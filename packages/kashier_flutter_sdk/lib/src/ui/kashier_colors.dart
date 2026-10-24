import 'package:flutter/material.dart';

/// Kashier brand colors used across all SDK payment UI.
///
/// These match the main Kashier application palette so the SDK
/// feels native and authentic inside the merchant's app.
class KashierColors {
  KashierColors._();

  // ── Brand ────────────────────────────────────────────────
  static const Color primary = Color(0xFF001F5F);
  static const Color secondary = Color(0xFF254177);
  static const Color danger = Color(0xFFA50017);
  static const Color success = Color(0xFF4AAB4E);
  static const Color warning = Color(0xFFFEA71C);
  static const Color tertiary = Color(0xFFF5F6F6);

  // ── Surface ─────────────────────────────────────────────
  static const Color surfaceBackground = Color(0xFFFFFFFF);
  static const Color surfaceSheet = Color(0xFFFFFFFF);
  static const Color surfaceInput = Color(0xFFF5F6F6);
  static const Color surfaceDisabled = Color(0xFFE6E8E8);
  static const Color surfaceOverlay = Color(0x80000000);

  // ── Content ──────────────────────────────────────────────
  static const Color contentPrimary = Color(0xFF202020);
  static const Color contentSecondary = Color(0xFF556767);
  static const Color contentDisabled = Color(0xFF919C9C);
  static const Color contentHint = Color(0xFF697979);

  // ── Stroke ───────────────────────────────────────────────
  static const Color strokeInput = Color(0xFFE6E8E8);
  static const Color strokeFocused = Color(0xFF001F5F);
  static const Color strokeDisabled = Color(0xFF919C9C);
  static const Color strokeDanger = Color(0xFFA50017);
  static const Color strokeSuccess = Color(0xFF4AAB4E);

  // ── Feedback ────────────────────────────────────────────
  static const Color feedbackSuccess = Color(0xFF4AAB4E);
  static const Color feedbackSuccessLight = Color(0xFFE8F5E9);
  static const Color feedbackError = Color(0xFFA50017);
  static const Color feedbackErrorLight = Color(0xFFFDE8EC);
  static const Color feedbackWarning = Color(0xFFFEA71C);
  static const Color feedbackWarningLight = Color(0xFFFFF8E1);

  // ── Misc ─────────────────────────────────────────────────
  static const Color placeholder = Color(0xFFB3BBBB);

  /// Resolves the primary color from an optional merchant brand color hex
  /// string. Returns the default Kashier primary if null or invalid.
  static Color resolvedPrimary(String? brandColor) {
    if (brandColor == null || brandColor.isEmpty) return primary;
    try {
      var hex = brandColor.replaceFirst('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return primary;
    }
  }
}
