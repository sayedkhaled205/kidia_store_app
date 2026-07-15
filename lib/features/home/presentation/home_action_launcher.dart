import 'package:url_launcher/url_launcher.dart';

abstract final class HomeActionLauncher {
  const HomeActionLauncher._();

  static Uri? parseExternalHttpUri(String value) {
    final Uri? uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasScheme ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }

    return uri;
  }

  static Future<bool> launchExternal(String value) async {
    final Uri? uri = parseExternalHttpUri(value);
    if (uri == null) {
      return false;
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}
