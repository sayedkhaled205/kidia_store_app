import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/auth/presentation/embedded_store_auth_view.dart';

void main() {
  final policy = StoreAuthNavigationPolicy(
    store: Uri.parse('https://store.example/shop'),
    callbackScheme: 'mobishop-login-test',
  );
  test('only merchant HTTPS pages stay embedded as the main document', () {
    expect(
      policy.classify(
        'https://store.example/login/?step=otp',
        isMainFrame: true,
      ),
      StoreAuthNavigation.allow,
    );
    for (final url in [
      'https://accounts.google.com/signin',
      'https://store.example.evil.test/login',
      'https://store.example:444/login',
    ]) {
      expect(
        policy.classify(url, isMainFrame: true),
        StoreAuthNavigation.externalAuthentication,
      );
    }
    for (final url in [
      'http://store.example/login',
      'https://user:pass@store.example/',
      'javascript:alert(1)',
      'data:text/html,login',
      'file:///login',
      'intent://login',
      'about:blank',
    ]) {
      expect(
        policy.classify(url, isMainFrame: true),
        StoreAuthNavigation.block,
      );
    }
  });
  test(
    'only exact callback scheme is intercepted and only in the main frame',
    () {
      expect(
        policy.classify(
          'mobishop-login-test://auth/complete?code=opaque',
          isMainFrame: true,
        ),
        StoreAuthNavigation.callback,
      );
      // The service, not page JavaScript, validates the host/path/state/code.
      expect(
        policy.classify('mobishop-login-test://wrong/path', isMainFrame: true),
        StoreAuthNavigation.callback,
      );
      expect(
        policy.classify(
          'mobishop-login-other://auth/complete',
          isMainFrame: true,
        ),
        StoreAuthNavigation.block,
      );
      expect(
        policy.classify(
          'mobishop-login-test://auth/complete',
          isMainFrame: false,
        ),
        StoreAuthNavigation.block,
      );
    },
  );
  test('HTTPS challenge frames cannot request external authentication', () {
    expect(
      policy.classify(
        'https://www.google.com/recaptcha/api2/anchor',
        isMainFrame: false,
      ),
      StoreAuthNavigation.allow,
    );
    expect(
      policy.classify(
        'http://www.google.com/recaptcha/api2/anchor',
        isMainFrame: false,
      ),
      StoreAuthNavigation.block,
    );
  });
}
