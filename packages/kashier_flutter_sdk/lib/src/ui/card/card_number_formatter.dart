import 'package:flutter/services.dart';

/// Formats card number input as `XXXX XXXX XXXX XXXX`.
///
/// Strips non-digits, limits to 16 digits, and inserts a space every 4 digits.
/// Correctly maintains cursor position after formatting.
class CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final trimmed =
        digitsOnly.length > 16 ? digitsOnly.substring(0, 16) : digitsOnly;

    final buffer = StringBuffer();
    for (int i = 0; i < trimmed.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(trimmed[i]);
    }
    final formatted = buffer.toString();

    // Calculate new cursor position.
    // Count how many digits are before the cursor in the new (unformatted) value.
    int digitsBeforeCursor = 0;
    final cursorPos =
        newValue.selection.baseOffset.clamp(0, newValue.text.length);
    for (int i = 0; i < cursorPos && i < newValue.text.length; i++) {
      if (RegExp(r'\d').hasMatch(newValue.text[i])) {
        digitsBeforeCursor++;
      }
    }

    // Map digit count back to formatted string position.
    int newCursorPos = 0;
    int digitsSeen = 0;
    for (int i = 0; i < formatted.length; i++) {
      if (digitsSeen == digitsBeforeCursor) break;
      newCursorPos = i + 1;
      if (formatted[i] != ' ') digitsSeen++;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: newCursorPos.clamp(0, formatted.length),
      ),
    );
  }
}
