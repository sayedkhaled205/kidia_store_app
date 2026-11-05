import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/privacy_page_block.dart';
import 'store_privacy_body_loader.dart';

/// Full scrollable screen showing the merchant's real published privacy
/// page content (not a browser/webview and not site navigation chrome).
class StorePrivacyScreen extends ConsumerStatefulWidget {
  const StorePrivacyScreen({required this.uri, super.key});
  final Uri uri;

  @override
  ConsumerState<StorePrivacyScreen> createState() => _StorePrivacyScreenState();
}

class _StorePrivacyScreenState extends ConsumerState<StorePrivacyScreen> {
  late Future<List<PrivacyBlock>> _future;
  final _recognizers = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    _future = ref.read(storePrivacyBodyLoaderProvider)(widget.uri);
  }

  void _retry() {
    setState(() {
      _future = ref.read(storePrivacyBodyLoaderProvider)(widget.uri);
    });
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(ar ? 'سياسة الخصوصية' : 'Privacy Policy'),
      ),
      body: FutureBuilder<List<PrivacyBlock>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final blocks = snapshot.data;
          if (snapshot.hasError || blocks == null || blocks.isEmpty) {
            return _buildError(ar);
          }
          _clearRecognizers();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final block in blocks) _buildBlock(block)],
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(bool ar) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ar
                  ? 'تعذر تحميل سياسة الخصوصية. حاول مرة أخرى.'
                  : 'Unable to load the privacy policy. Please retry.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              key: const Key('store-privacy-retry'),
              onPressed: _retry,
              child: Text(ar ? 'إعادة المحاولة' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }

  void _clearRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  Widget _buildBlock(PrivacyBlock block) {
    final start = RegExp(
      r'[A-Za-z\u0590-\u08ff]',
    ).firstMatch(block.spans.map((span) => span.text).join())?.group(0);
    final direction = start == null
        ? Directionality.of(context)
        : start.codeUnitAt(0) >= 0x0590
        ? TextDirection.rtl
        : TextDirection.ltr;
    final theme = Theme.of(context).textTheme;
    final style = switch (block.type) {
      PrivacyBlockType.heading1 => theme.headlineSmall,
      PrivacyBlockType.heading2 => theme.titleLarge,
      PrivacyBlockType.heading3 => theme.titleMedium,
      PrivacyBlockType.paragraph => theme.bodyMedium,
      PrivacyBlockType.listItem => theme.bodyMedium,
    };
    final text = SelectableText.rich(
      TextSpan(children: [for (final span in block.spans) _span(span, style)]),
    );
    final padded = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: block.type == PrivacyBlockType.listItem
          ? Padding(
              padding: const EdgeInsetsDirectional.only(start: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: text),
                ],
              ),
            )
          : text,
    );
    return SizedBox(
      width: double.infinity,
      child: Directionality(textDirection: direction, child: padded),
    );
  }

  InlineSpan _span(PrivacyTextSpan span, TextStyle? style) {
    final link = span.linkUri;
    if (link == null) return TextSpan(text: span.text, style: style);
    final recognizer = TapGestureRecognizer()
      ..onTap = () => launchUrl(link, mode: LaunchMode.externalApplication);
    _recognizers.add(recognizer);
    return TextSpan(
      text: span.text,
      style: style?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
      recognizer: recognizer,
    );
  }
}
