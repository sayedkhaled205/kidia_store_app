import 'package:shared_preferences/shared_preferences.dart';

/// Optional, pseudonymous attribution. Never sends an account, token or order data.
abstract final class PushCheckoutAttribution {
  static String _key(Uri endpoint) => 'mobishop_push_click_${endpoint.origin}';

  static Future<void> opened(Uri endpoint) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      _key(endpoint),
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  static Future<Map<String, String>> headers(Uri checkout) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final clicked = preferences.getInt(_key(checkout));
      final client = preferences.getString('mobishop_push_client_id') ?? '';
      if (clicked == null ||
          !RegExp(r'^[a-zA-Z0-9_-]{8,160}$').hasMatch(client)) {
        return const {};
      }
      final age = DateTime.now().millisecondsSinceEpoch - clicked;
      if (age < 0 || age > const Duration(days: 7).inMilliseconds) {
        return const {};
      }
      return {'X-MobiShop-Push-Client': client};
    } catch (_) {
      // Optional evidence must never prevent an order submission.
      return const {};
    }
  }
}
