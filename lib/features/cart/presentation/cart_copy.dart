import 'package:flutter/widgets.dart';

class CartCopy {
  const CartCopy._(this.isArabic);

  final bool isArabic;

  factory CartCopy.of(BuildContext context) {
    return CartCopy._(
      Localizations.localeOf(context).languageCode.toLowerCase() == 'ar',
    );
  }

  String get title => isArabic ? 'سلة التسوق' : 'Shopping cart';
  String get refresh => isArabic ? 'تحديث السلة' : 'Refresh cart';
  String get loading => isArabic ? 'جارٍ تحميل السلة' : 'Loading your cart';
  String get emptyTitle => isArabic ? 'سلتك فارغة' : 'Your cart is empty';
  String get emptyMessage => isArabic
      ? 'أضف المنتجات التي تحبها لتجدها هنا.'
      : 'Add products you love and they will appear here.';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Try again';
  String get loadFailed => isArabic
      ? 'تعذر تحميل السلة من المتجر.'
      : 'The store could not load your cart.';
  String get remove => isArabic ? 'حذف' : 'Remove';
  String get removeTitle => isArabic ? 'حذف المنتج؟' : 'Remove this item?';
  String removeMessage(String name) => isArabic
      ? 'هل تريد حذف «$name» من السلة؟'
      : 'Remove “$name” from your cart?';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get removed => isArabic ? 'تم حذف المنتج' : 'Item removed';
  String get decreaseQuantity =>
      isArabic ? 'تقليل الكمية' : 'Decrease quantity';
  String get increaseQuantity =>
      isArabic ? 'زيادة الكمية' : 'Increase quantity';
  String quantity(int value) => isArabic ? 'الكمية $value' : 'Quantity $value';
  String get lowStock => isArabic ? 'الكمية محدودة' : 'Low stock';
  String get each => isArabic ? 'للقطعة' : 'each';
  String get couponTitle => isArabic ? 'كود الخصم' : 'Coupon';
  String get couponHint => isArabic ? 'اكتب كود الخصم' : 'Enter coupon code';
  String get apply => isArabic ? 'تطبيق' : 'Apply';
  String get couponRequired =>
      isArabic ? 'اكتب كود الخصم أولًا.' : 'Enter a coupon code first.';
  String get orderSummary => isArabic ? 'ملخص الطلب' : 'Order summary';
  String get subtotal => isArabic ? 'الإجمالي الفرعي' : 'Subtotal';
  String get discount => isArabic ? 'الخصم' : 'Discount';
  String get shipping => isArabic ? 'الشحن' : 'Shipping';
  String get fees => isArabic ? 'الرسوم' : 'Fees';
  String get tax => isArabic ? 'الضريبة' : 'Tax';
  String get total => isArabic ? 'الإجمالي' : 'Total';
  String get shippingAtCheckout =>
      isArabic ? 'يُحسب عند إكمال الطلب' : 'Calculated at checkout';
  String get checkout =>
      isArabic ? 'متابعة إكمال الطلب' : 'Continue to checkout';
  String get checkoutUnavailable => isArabic
      ? 'إكمال الطلب غير مربوط بعد في هذا الإصدار.'
      : 'Checkout is not connected in this build yet.';
  String get updating => isArabic ? 'جارٍ التحديث…' : 'Updating…';
  String itemCount(int count) => isArabic
      ? count == 1
            ? 'منتج واحد'
            : '$count منتجات'
      : count == 1
      ? '1 item'
      : '$count items';
}
