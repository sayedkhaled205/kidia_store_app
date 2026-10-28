/// Presentation only. Phone accounts retain their server-issued identifier for
/// authentication, but reserved placeholder addresses are not customer emails.
String customerDisplayEmail(String? value) {
  final email = value?.trim() ?? '';
  final parts = email.split('@');
  if (parts.length != 2 ||
      parts.first.isEmpty ||
      parts.last.isEmpty ||
      RegExp(r'\s').hasMatch(email)) {
    return '';
  }
  final domain = parts.last.toLowerCase();
  if (domain == 'invalid' || domain.endsWith('.invalid')) return '';
  return email;
}
