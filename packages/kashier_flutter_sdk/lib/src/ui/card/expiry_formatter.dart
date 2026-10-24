import 'package:flutter/services.dart';

/// Formats expiry date input as `MM/YY`.
///
/// Strips non-digits, limits to 4 digits, and auto-inserts the slash
/// after the month. Correctly maintains cursor position.
class ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed =
        digitsOnly.length > 4 ? digitsOnly.substring(0, 4) : digitsOnly;

    final buffer = StringBuffer();
    for (int i = 0; i < trimmed.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(trimmed[i]);
    }
    final formatted = buffer.toString();

    // Calculate cursor position based on digit count before cursor.
    int digitsBeforeCursor = 0;
    final cursorPos =
        newValue.selection.baseOffset.clamp(0, newValue.text.length);
    for (int i = 0; i < cursorPos && i < newValue.text.length; i++) {
      if (RegExp(r'\d').hasMatch(newValue.text[i])) {
        digitsBeforeCursor++;
      }
    }

    int newCursorPos = 0;
    int digitsSeen = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (digitsSeen == digitsBeforeCursor) break;
      newCursorPos = i + 1;
      if (formatted[i] != '/') digitsSeen++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: newCursorPos.clamp(0, formatted.length),
      ),
    );
  }
}
