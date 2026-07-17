/// Converts an Egyptian international phone number to its familiar local
/// representation while leaving other countries untouched.
String localEgyptianPhoneNumber(String value) {
  final String source = value.trim();
  if (source.isEmpty) {
    return '';
  }

  final String digits = source.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('00201') && digits.length == 14) {
    return '0${digits.substring(4)}';
  }
  if (digits.startsWith('201') && digits.length == 12) {
    return '0${digits.substring(2)}';
  }
  return source;
}
