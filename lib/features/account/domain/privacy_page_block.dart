/// Parsed, display-ready pieces of a merchant's published privacy page.
/// Never holds raw HTML, scripts or chrome (nav/footer) from the source page.
enum PrivacyBlockType { heading1, heading2, heading3, paragraph, listItem }

/// A run of text, optionally a tappable web (http/https) or mail link.
/// [linkUri] is pre-sanitized: only http, https or mailto schemes survive
/// parsing, so the UI can trust it without re-validating before launching.
class PrivacyTextSpan {
  const PrivacyTextSpan({required this.text, this.linkUri});
  final String text;
  final Uri? linkUri;
}

class PrivacyBlock {
  const PrivacyBlock({required this.type, required this.spans});
  final PrivacyBlockType type;
  final List<PrivacyTextSpan> spans;
}
