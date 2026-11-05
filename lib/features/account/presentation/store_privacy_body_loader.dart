import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/privacy_page_fetcher.dart';
import '../data/privacy_page_parser.dart';
import '../domain/privacy_page_block.dart';

typedef StorePrivacyBodyLoader = Future<List<PrivacyBlock>> Function(Uri uri);

Future<List<PrivacyBlock>> _loadWithDio(Uri uri) async {
  final html = await PrivacyPageFetcher().fetchHtml(uri);
  return parsePrivacyPage(html);
}

/// Injectable loader for the merchant's published privacy page body.
/// Replaces the old external-browser launcher: the app now fetches and
/// renders the real page content inside a native screen.
final storePrivacyBodyLoaderProvider = Provider<StorePrivacyBodyLoader>(
  (ref) => _loadWithDio,
);
