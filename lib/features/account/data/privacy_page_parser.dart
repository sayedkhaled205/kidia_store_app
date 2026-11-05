import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../domain/privacy_page_block.dart';

const _ignoredTags = {
  'nav',
  'footer',
  'header',
  'script',
  'style',
  'noscript',
  'aside',
  'form',
  'button',
  'iframe',
  'svg',
};

const _containerTags = {'div', 'section', 'article', 'span'};

/// Reads the merchant's published page and keeps only the readable article
/// text (article/.entry-content/main), in source order, dropping site chrome
/// (nav, footer, scripts, styles) and anything explicitly hidden.
List<PrivacyBlock> parsePrivacyPage(String htmlSource) {
  final document = html_parser.parse(htmlSource);
  final root = _findContentRoot(document);
  if (root == null) return const [];
  final blocks = <PrivacyBlock>[];
  _collectBlocks(root, blocks);
  return blocks;
}

dom.Element? _findContentRoot(dom.Document document) {
  for (final selector in [
    '.entry-content',
    '.shopify-policy__body',
    'article',
    'main',
    '#wrap',
  ]) {
    final match = document.querySelector(selector);
    if (match != null) return match;
  }
  return document.body;
}

bool _isHidden(dom.Element element) {
  final style = element.attributes['style']?.toLowerCase() ?? '';
  if (style.contains('display:none') ||
      style.contains('display: none') ||
      style.contains('visibility:hidden') ||
      style.contains('visibility: hidden')) {
    return true;
  }
  if (element.attributes.containsKey('hidden')) return true;
  if (element.attributes['aria-hidden'] == 'true') return true;
  return false;
}

void _collectBlocks(dom.Element root, List<PrivacyBlock> blocks) {
  for (final node in root.nodes) {
    if (node is dom.Text && node.text.trim().isNotEmpty) {
      blocks.add(
        PrivacyBlock(
          type: PrivacyBlockType.paragraph,
          spans: [PrivacyTextSpan(text: node.text.trim())],
        ),
      );
    }
    if (node is! dom.Element) continue;
    final tag = node.localName?.toLowerCase();
    if (tag == null || _ignoredTags.contains(tag) || _isHidden(node)) continue;
    switch (tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        _addTextBlock(blocks, _headingType(tag), node);
      case 'p':
        _addTextBlock(blocks, PrivacyBlockType.paragraph, node);
      case 'ul':
      case 'ol':
        for (final li in node.children) {
          if (li.localName?.toLowerCase() != 'li' || _isHidden(li)) continue;
          _addTextBlock(blocks, PrivacyBlockType.listItem, li);
        }
      default:
        if (_containerTags.contains(tag) && node.children.isNotEmpty) {
          _collectBlocks(node, blocks);
        } else {
          _addTextBlock(blocks, PrivacyBlockType.paragraph, node);
        }
    }
  }
}

void _addTextBlock(
  List<PrivacyBlock> blocks,
  PrivacyBlockType type,
  dom.Element element,
) {
  final spans = _extractSpans(element);
  if (spans.isNotEmpty) blocks.add(PrivacyBlock(type: type, spans: spans));
}

PrivacyBlockType _headingType(String tag) => switch (tag) {
  'h1' => PrivacyBlockType.heading1,
  'h2' => PrivacyBlockType.heading2,
  _ => PrivacyBlockType.heading3,
};

List<PrivacyTextSpan> _extractSpans(dom.Element element) {
  final spans = <PrivacyTextSpan>[];
  void visit(dom.Node node, Uri? inheritedLink) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.isNotEmpty) {
        spans.add(PrivacyTextSpan(text: text, linkUri: inheritedLink));
      }
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName?.toLowerCase();
    if (tag == null || _ignoredTags.contains(tag) || _isHidden(node)) {
      return;
    }
    if (tag == 'br') {
      spans.add(const PrivacyTextSpan(text: '\n'));
      return;
    }
    var link = inheritedLink;
    if (tag == 'a') link = _safeContentLink(node.attributes['href']);
    for (final child in node.nodes) {
      visit(child, link);
    }
  }

  for (final child in element.nodes) {
    visit(child, null);
  }
  return spans;
}

Uri? _safeContentLink(String? href) {
  if (href == null) return null;
  final uri = Uri.tryParse(href.trim());
  if (uri == null) return null;
  if (uri.hasAuthority && uri.scheme != 'https') return null;
  return uri.scheme.isEmpty || uri.scheme == 'https' ? uri : null;
}
