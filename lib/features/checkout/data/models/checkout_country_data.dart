abstract final class CheckoutCountryData {
  const CheckoutCountryData._();

  static Map<String, String> statesFor(String countryCode) {
    return switch (countryCode.trim().toUpperCase()) {
      'EG' => egyptianGovernorates,
      _ => const <String, String>{},
    };
  }

  /// WooCommerce state codes used by shipping zones in Egypt.
  ///
  /// The plugin normally supplies the store-localized labels. This map keeps
  /// checkout functional when an older plugin response exposes `billing_state`
  /// as a plain text field and is deliberately keyed by WooCommerce codes.
  static const Map<String, String> egyptianGovernorates = <String, String>{
    'EGALX': 'الإسكندرية',
    'EGASN': 'أسوان',
    'EGAST': 'أسيوط',
    'EGBA': 'البحر الأحمر',
    'EGBH': 'البحيرة',
    'EGBNS': 'بني سويف',
    'EGC': 'القاهرة',
    'EGDK': 'الدقهلية',
    'EGDT': 'دمياط',
    'EGFYM': 'الفيوم',
    'EGGH': 'الغربية',
    'EGGZ': 'الجيزة',
    'EGIS': 'الإسماعيلية',
    'EGJS': 'جنوب سيناء',
    'EGKB': 'القليوبية',
    'EGKFS': 'كفر الشيخ',
    'EGKN': 'قنا',
    'EGLX': 'الأقصر',
    'EGMN': 'المنيا',
    'EGMNF': 'المنوفية',
    'EGMT': 'مطروح',
    'EGPTS': 'بورسعيد',
    'EGSHG': 'سوهاج',
    'EGSHR': 'الشرقية',
    'EGSIN': 'شمال سيناء',
    'EGSUZ': 'السويس',
    'EGWAD': 'الوادي الجديد',
  };
}
