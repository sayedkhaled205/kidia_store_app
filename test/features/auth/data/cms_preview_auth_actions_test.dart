import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/auth/data/cms_preview_auth_actions.dart';
import 'package:mobishop_store_app/features/auth/domain/repositories/auth_repository.dart';

void main() {
  test(
    'preview keeps connected methods, strips SDK options and blocks login',
    () async {
      final actions = CmsPreviewAuthActions(
        () async => {
          'version': 1,
          'enabled': true,
          'methods': {
            'google': true,
            'phone_otp': true,
            'email_password': true,
          },
          'google': {'server_client_id': 'not-for-preview'},
          'firebase': {'apiKey': 'not-for-preview'},
        },
        isArabic: true,
      );
      final config = await actions.config();
      expect(config.allows('google'), isTrue);
      expect(config.supportsPhone, isTrue);
      expect(config.google, isEmpty);
      expect(config.firebase, isEmpty);
      final previewOnly = isA<AuthRepositoryException>().having(
        (e) => e.code,
        'code',
        'preview-only',
      );
      await expectLater(actions.google(), throwsA(previewOnly));
      await expectLater(
        actions.identify('customer@example.com'),
        throwsA(previewOnly),
      );
      await expectLater(actions.sendOtp('+201000000000'), throwsA(previewOnly));
      await actions.cancel();
    },
  );

  test(
    'disabled and failed configuration never invent Google availability',
    () async {
      final actions = CmsPreviewAuthActions(
        () async => {
          'version': 1,
          'enabled': false,
          'methods': {'google': true},
        },
        isArabic: false,
      );
      expect((await actions.config()).allows('google'), isFalse);
      final missing = CmsPreviewAuthActions(
        () async => {'error': 'offline'},
        isArabic: false,
      );
      await expectLater(missing.config(), throwsFormatException);
    },
  );
}
