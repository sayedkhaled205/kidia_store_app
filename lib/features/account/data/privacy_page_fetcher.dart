import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/app_design/store_privacy_provider.dart';
import '../../../core/commerce/commerce_connection.dart';
import '../../../core/config/app_config.dart';

class PrivacyPageFetcher {
  Future<String> fetchHtml(Uri policy) async {
    if (safeStorePrivacyUri(policy.toString()) == null) {
      throw const FormatException('Invalid policy URL');
    }
    final dio = Dio(
      BaseOptions(
        followRedirects: false,
        validateStatus: (status) => status != null && status < 400,
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 12),
      ),
    );
    try {
      // The preview runs on the builder domain. Read a matching public article
      // from the merchant origin, just as the installed Woo app does.
      final store = AppConfig.isCmsPreview
          ? policy.resolve('/')
          : safeStorePrivacyUri(AppConfig.apiBaseUrl);
      if (AppConfig.commercePlatform == CommercePlatform.wooCommerce &&
          store != null &&
          store.origin == policy.origin &&
          !policy.hasQuery &&
          policy.pathSegments.any((s) => s.isNotEmpty)) {
        final uri = store.replace(
          path:
              '${store.path.replaceFirst(RegExp(r'/+$'), '')}/wp-json/wp/v2/pages',
          queryParameters: {
            'slug': policy.pathSegments.lastWhere((s) => s.isNotEmpty),
            '_fields': 'link,content',
          },
        );
        try {
          final rows = jsonDecode(await _read(dio, uri, 'application/json'));
          if (rows is List) {
            for (final row in rows.whereType<Map>()) {
              final content = row['content'];
              if (row['link'] == policy.toString() &&
                  content is Map &&
                  content['protected'] == false &&
                  content['rendered'] is String) {
                return '<article>${content['rendered']}</article>';
              }
            }
          }
        } on Exception {
          // Older stores may disable the public pages API.
        }
      }
      return await _read(dio, policy, 'text/html');
    } finally {
      dio.close(force: true);
    }
  }

  Future<String> _read(Dio dio, Uri initial, String accept) async {
    var uri = initial;
    for (var redirects = 0; redirects <= 3; redirects++) {
      final response = await dio.getUri<ResponseBody>(
        uri,
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': accept},
        ),
      );
      final body = response.data!;
      if (response.statusCode != 200) {
        await body.stream.listen((_) {}).cancel();
        final location = response.headers.value('location');
        final next = location == null
            ? null
            : safeStorePrivacyUri(uri.resolve(location).toString());
        if (next == null ||
            next.origin != initial.origin ||
            ![301, 302, 303, 307, 308].contains(response.statusCode)) {
          break;
        }
        uri = next;
        continue;
      }
      final bytes = <int>[];
      await for (final chunk in body.stream) {
        if (bytes.length + chunk.length > 2 * 1024 * 1024) {
          throw const FormatException('Policy document too large');
        }
        bytes.addAll(chunk);
      }
      return utf8.decode(bytes);
    }
    throw const FormatException('Policy document unavailable');
  }
}
