import 'package:flutter/widgets.dart';

class CatalogCopy {
  const CatalogCopy._(this.isArabic);

  final bool isArabic;

  factory CatalogCopy.of(BuildContext context) {
    return CatalogCopy._(
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar',
    );
  }

  String get categories => isArabic ? 'الأقسام' : 'Categories';
  String get products => isArabic ? 'المنتجات' : 'Products';
  String get search => isArabic ? 'البحث' : 'Search';
  String get searchHint => isArabic ? 'ابحث عن منتج' : 'Search products';
  String get searchPrompt => isArabic
      ? 'اكتب اسم المنتج الذي تبحث عنه'
      : 'Enter a product name to start searching';
  String get viewProducts => isArabic ? 'عرض المنتجات' : 'View products';
  String get noCategories => isArabic
      ? 'لا توجد أقسام متاحة حاليًا'
      : 'No categories are available yet';
  String get noProducts => isArabic
      ? 'لا توجد منتجات تطابق اختيارك'
      : 'No products match your selection';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Try again';
  String get refresh => isArabic ? 'تحديث' : 'Refresh';
  String get connectionError => isArabic
      ? 'تعذر الاتصال بالمتجر. تأكد من الإنترنت وحاول مجددًا.'
      : 'Could not reach the store. Check your connection and try again.';
  String get storeError => isArabic
      ? 'تعذر تحميل البيانات من المتجر.'
      : 'The store could not load this catalog data.';
  String get sort => isArabic ? 'الترتيب' : 'Sort';
  String get filter => isArabic ? 'تصفية' : 'Filter';
  String get size => isArabic ? 'المقاس' : 'Size';
  String get chooseSize => isArabic ? 'اختاري المقاس' : 'Choose a size';
  String get allSizes => isArabic ? 'كل المقاسات' : 'All sizes';
  String get noSizes => isArabic
      ? 'لا توجد مقاسات متاحة لهذه المجموعة.'
      : 'No sizes are available for this collection.';
  String get filters => isArabic ? 'الفلاتر' : 'Filters';
  String get apply => isArabic ? 'تطبيق' : 'Apply';
  String get reset => isArabic ? 'إعادة ضبط' : 'Reset';
  String get brand => isArabic ? 'البراند' : 'Brand';
  String get allBrands => isArabic ? 'كل البراندات' : 'All brands';
  String get onSaleOnly => isArabic ? 'العروض فقط' : 'On sale only';
  String get minimumPrice => isArabic ? 'أقل سعر' : 'Minimum price';
  String get maximumPrice => isArabic ? 'أعلى سعر' : 'Maximum price';
  String get invalidPrice =>
      isArabic ? 'أدخل رقمًا صحيحًا' : 'Enter a valid number';
  String get invalidRange => isArabic
      ? 'أقل سعر يجب ألا يتجاوز أعلى سعر'
      : 'Minimum price cannot exceed maximum price';
  String get loadingMore => isArabic ? 'جارٍ تحميل المزيد...' : 'Loading more…';
  String get loadMoreFailed =>
      isArabic ? 'تعذر تحميل المزيد' : 'Could not load more products';
  String get outOfStock => isArabic ? 'نفد المخزون' : 'Out of stock';
  String get sale => isArabic ? 'خصم' : 'Sale';
  String get details => isArabic ? 'عرض التفاصيل' : 'View details';
  String get expand =>
      isArabic ? 'إظهار الأقسام الفرعية' : 'Show subcategories';
  String get collapse =>
      isArabic ? 'إخفاء الأقسام الفرعية' : 'Hide subcategories';

  String sortLabel(Object value) {
    final String name = value.toString().split('.').last;
    if (isArabic) {
      return switch (name) {
        'newest' => 'الأحدث',
        'priceLowToHigh' => 'السعر: من الأقل للأعلى',
        'priceHighToLow' => 'السعر: من الأعلى للأقل',
        'popularity' => 'الأكثر شعبية',
        'rating' => 'الأعلى تقييمًا',
        'name' => 'الاسم',
        _ => 'الأنسب',
      };
    }

    return switch (name) {
      'newest' => 'Newest',
      'priceLowToHigh' => 'Price: low to high',
      'priceHighToLow' => 'Price: high to low',
      'popularity' => 'Most popular',
      'rating' => 'Top rated',
      'name' => 'Name',
      _ => 'Relevance',
    };
  }
}
