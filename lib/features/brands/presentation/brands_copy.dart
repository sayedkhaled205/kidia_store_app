import 'package:flutter/widgets.dart';

class BrandsCopy {
  const BrandsCopy._(this.isArabic);

  final bool isArabic;

  factory BrandsCopy.of(BuildContext context) {
    return BrandsCopy._(
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar',
    );
  }

  String get title => isArabic ? 'العلامات التجارية' : 'Brands';
  String get searchHint => isArabic ? 'ابحث عن علامة تجارية' : 'Search brands';
  String get noBrands => isArabic
      ? 'لا توجد علامات تجارية متاحة حاليًا'
      : 'No brands are available yet';
  String get noResults =>
      isArabic ? 'لا توجد علامات تطابق بحثك' : 'No brands match your search';
  String get unsupportedTitle => isArabic
      ? 'العلامات غير مدعومة في هذا المتجر'
      : 'Brands are not supported by this store';
  String get unsupportedBody => isArabic
      ? 'هذه النسخة من WooCommerce لا توفر Brands API. باقي الكتالوج سيظل يعمل بشكل طبيعي.'
      : 'This WooCommerce version does not expose the Brands API. The rest of the catalog remains available.';
  String get connectionError => isArabic
      ? 'تعذر الاتصال بالمتجر. تحقق من الإنترنت وحاول مجددًا.'
      : 'Could not reach the store. Check your connection and try again.';
  String get storeError => isArabic
      ? 'تعذر تحميل العلامات من المتجر.'
      : 'The store could not load its brands.';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Try again';
  String get clearSearch => isArabic ? 'مسح البحث' : 'Clear search';
  String get loadingMore => isArabic ? 'جارٍ تحميل المزيد...' : 'Loading more…';
  String get moreFailed =>
      isArabic ? 'تعذر تحميل المزيد' : 'Could not load more brands';
  String count(int value) => isArabic ? '$value منتج' : '$value products';
}
