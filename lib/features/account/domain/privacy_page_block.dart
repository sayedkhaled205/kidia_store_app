/// Parsed, display-ready pieces of a merchant's published privacy page.
/// Never holds raw HTML, scripts or chrome (nav/footer) from the source page.
enum PrivacyBlockType { heading1, heading2, heading3, paragraph, listItem }

/// Article text and an optional link for the native policy reader to resolve.
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
