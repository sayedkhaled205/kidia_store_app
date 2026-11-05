import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;
import 'commerce_connection.dart';
import 'shopify_storefront_client.dart';

Uri? safeStorePrivacyUri(String value) {
  if (value.length > 2048) return null;
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
          uri.scheme == 'https' &&
          uri.host.isNotEmpty &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}

Uri? publicOdooPrivacyLink(String markup, Uri origin) {
  final document = html.parse(markup);
  final links = document.querySelectorAll(
    'a[rel~=privacy-policy],footer a[href],#footer a[href],#footerwrap a[href]',
  );
  for (final link in links) {
    final label = link.text.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final declared = (link.attributes['rel'] ?? '')
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .contains('privacy-policy');
    if (!declared &&
        !{
          'privacy policy',
          'privacy notice',
          'privacy',
          'سياسة الخصوصية',
          'سياسة خصوصية',
          'politique de confidentialité',
        }.contains(label)) {
      continue;
    }
    final href = link.attributes['href']?.trim();
    if (href == null || href.isEmpty || href.startsWith('#')) continue;
    final parsed = Uri.tryParse(href);
    if (parsed == null) continue;
    final candidate = origin.resolveUri(parsed);
    final safe = safeStorePrivacyUri(candidate.toString());
    if (safe != null && safe.origin == origin.origin && safe != origin) {
      return safe;
    }
  }
  return null;
}

Future<Uri?> discoverPublicPolicy(CommerceConnection store) async {
  if (store.platform == CommercePlatform.shopify) {
    final client = ShopifyStorefrontClient(connection: store);
    try {
      final data = await client.query(
        'query StorePolicy { shop { privacyPolicy { url } } }',
      );
      final shop = data['shop'];
      final policy = shop is Map ? shop['privacyPolicy'] : null;
      final value = policy is Map ? policy['url'] : null;
      return value is String ? safeStorePrivacyUri(value) : null;
    } finally {
      client.close();
    }
  }
  if (store.platform != CommercePlatform.odoo) return null;
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 6),
      receiveTimeout: const Duration(seconds: 8),
      followRedirects: false,
      validateStatus: (s) => s != null && s < 400,
    ),
  );
  try {
    var url = store.storeOrigin;
    for (var hop = 0; hop < 4; hop++) {
      final response = await dio.getUri<ResponseBody>(
        url,
        options: Options(responseType: ResponseType.stream),
      );
      final body = response.data!;
      if (response.statusCode != 200) {
        await body.stream.listen((_) {}).cancel();
        final location = response.headers.value('location');
        if (location == null ||
            ![301, 302, 303, 307, 308].contains(response.statusCode)) {
          return null;
        }
        final next = safeStorePrivacyUri(url.resolve(location).toString());
        if (next == null || next.origin != store.storeOrigin.origin) {
          return null;
        }
        url = next;
        continue;
      }
      final bytes = <int>[];
      await for (final chunk in body.stream) {
        if (bytes.length + chunk.length > 2 * 1024 * 1024) return null;
        bytes.addAll(chunk);
      }
      return publicOdooPrivacyLink(utf8.decode(bytes), url);
    }
    return null;
  } finally {
    dio.close(force: true);
  }
}
