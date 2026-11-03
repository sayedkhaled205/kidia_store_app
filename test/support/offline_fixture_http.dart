import 'dart:io';

/// Keeps fixture-only image requests offline without replacing the native
/// integration binding or changing the real application networking code.
class OfflineFixtureHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..connectionFactory = (uri, proxyHost, proxyPort) async {
        throw const SocketException('Network disabled for customer fixtures');
      };
  }
}
