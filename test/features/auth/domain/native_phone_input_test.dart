import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/native_auth.dart';

void main() {
  const egypt = NativeAuthConfig(phoneCountryCode: '20');
  test(
    'local Egyptian phone uses store dialing code and accepts Arabic digits',
    () {
      expect(egypt.phoneHint, '01XXXXXXXXX');
      expect(egypt.normalizeOtpPhone('01012345678'), '+201012345678');
      expect(egypt.normalizeOtpPhone('٠١٠١٢٣٤٥٦٧٨'), '+201012345678');
      expect(egypt.normalizeOtpPhone('۰۱۰۱۲۳۴۵۶۷۸'), '+201012345678');
      expect(egypt.normalizeOtpPhone('010 1234 5678'), '+201012345678');
    },
  );
  test('incomplete, invalid and non-phone values cannot request SMS', () {
    for (final value in [
      '',
      '0101234567',
      '010123456789',
      '01412345678',
      'abc',
    ]) {
      expect(egypt.normalizeOtpPhone(value), isNull, reason: value);
    }
  });
  test('international and other stores retain their dialing code', () {
    expect(egypt.normalizeOtpPhone('+201012345678'), '+201012345678');
    expect(egypt.normalizeOtpPhone('00201012345678'), '+201012345678');
    const uk = NativeAuthConfig(phoneCountryCode: '44');
    expect(uk.normalizeOtpPhone('07700900123'), '+447700900123');
    expect(uk.phoneHint, isEmpty);
    expect(const NativeAuthConfig().normalizeOtpPhone('01012345678'), isNull);
    expect(
      const NativeAuthConfig().normalizeOtpPhone('+447700900123'),
      '+447700900123',
    );
  });
  test('public configuration reads only a valid store dialing code', () {
    expect(
      NativeAuthConfig.fromJson({'phone_country_code': '20'}).phoneCountryCode,
      '20',
    );
    expect(
      NativeAuthConfig.fromJson({
        'phone_country_code': 'invalid',
      }).phoneCountryCode,
      isEmpty,
    );
  });
}
