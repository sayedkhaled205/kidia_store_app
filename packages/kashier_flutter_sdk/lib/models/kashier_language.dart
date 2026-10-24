import 'package:flutter/widgets.dart';

/// Display language for the Kashier SDK UI.
///
/// The merchant app passes this at [KashierSDK.initialize] so the SDK
/// renders its payment sheets in the same language as the host app.
enum KashierLanguage {
  /// English.
  en,

  /// Arabic.
  ar;

  /// ISO 639-1 language code (`en` or `ar`).
  String get code => name;

  /// The [Locale] used internally by the SDK's overlay.
  Locale get locale => Locale(code);
}
