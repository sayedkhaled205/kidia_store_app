import 'package:flutter/widgets.dart';

import '../kashier_sdk.dart';
import '../../models/kashier_language.dart';

/// Simple AR/EN localization helper for the Kashier payment UI.
///
/// The active language is sourced from [KashierSDK.language], which the
/// merchant sets at [KashierSDK.initialize]. The [BuildContext] parameter
/// is retained on these helpers for API stability; it is not consulted.
class KashierLocalizations {
  KashierLocalizations._();

  /// Returns true when the SDK is configured for Arabic.
  static bool isArabic(BuildContext context) {
    return KashierSDK.language == KashierLanguage.ar;
  }

  /// Returns the appropriate string based on the SDK's configured language.
  static String localized(
    BuildContext context, {
    required String en,
    required String ar,
  }) {
    return isArabic(context) ? ar : en;
  }

  // Payment Landing Sheet
  static String payment(BuildContext context) =>
      localized(context, en: 'Payment', ar: 'الدفع');

  static String morePaymentMethods(BuildContext context) =>
      localized(context, en: 'More Payment Methods', ar: 'طرق دفع أخرى');

  // Method Selection Sheet
  static String choosePaymentMethod(BuildContext context) =>
      localized(context, en: 'Choose Payment Method', ar: 'اختر طريقة الدفع');

  static String wallet(BuildContext context) =>
      localized(context, en: 'Wallet', ar: 'المحفظة');

  static String walletSubtitle(BuildContext context) =>
      localized(context, en: 'Vodafone Cash & more', ar: 'فودافون كاش والمزيد');

  static String moreMethodsSoon(BuildContext context) => localized(
        context,
        en: 'More methods coming soon',
        ar: 'المزيد من الطرق قريباً',
      );

  // Wallet Phone Input Sheet
  static String payWithWallet(BuildContext context) =>
      localized(context, en: 'Pay with Wallet', ar: 'الدفع بالمحفظة');

  static String phoneHint(BuildContext context) =>
      localized(context, en: '01XXXXXXXXX', ar: '01XXXXXXXXX');

  static String phoneLabel(BuildContext context) =>
      localized(context, en: 'Phone Number', ar: 'رقم الهاتف');

  static String invalidPhone(BuildContext context) => localized(
        context,
        en: 'Enter a valid Egyptian phone number',
        ar: 'أدخل رقم هاتف مصري صحيح',
      );

  static String payAmount(
    BuildContext context,
    String amount,
    String currency,
  ) {
    final c = currencyDisplay(context, currency);
    return localized(context, en: 'Pay $amount $c', ar: 'ادفع $amount $c');
  }

  /// Human-readable currency name for display.
  ///
  /// Known ISO codes are translated for Arabic; unknown codes fall back
  /// to the raw code so server-driven currencies still render correctly.
  static String currencyDisplay(BuildContext context, String currency) {
    final code = currency.toUpperCase();
    if (!isArabic(context)) return code;
    return switch (code) {
      'EGP' => 'ج.م',
      'USD' => 'دولار أمريكي',
      'EUR' => 'يورو',
      'GBP' => 'جنيه إسترليني',
      'SAR' => 'ريال سعودي',
      'AED' => 'درهم إماراتي',
      _ => code,
    };
  }

  static String back(BuildContext context) =>
      localized(context, en: 'Back', ar: 'رجوع');

  // Waiting/Polling Sheet
  static String completeYourPayment(BuildContext context) =>
      localized(context, en: 'Complete Your Payment', ar: 'أكمل عملية الدفع');

  static String checkWalletApp(BuildContext context) => localized(
        context,
        en: 'Check your SMS or wallet app to approve the payment',
        ar: 'تحقق من الرسائل أو تطبيق المحفظة للموافقة على الدفع',
      );

  static String reloadStatus(BuildContext context) =>
      localized(context, en: 'Reload Payment Status', ar: 'تحديث حالة الدفع');

  static String resend(BuildContext context) =>
      localized(context, en: 'Resend', ar: 'إعادة الإرسال');

  static String notifying(BuildContext context) =>
      localized(context, en: 'Notifying', ar: 'جارٍ الإشعار');

  static String processing(BuildContext context) =>
      localized(context, en: 'Processing', ar: 'جارٍ المعالجة');

  static String successfulPayment(BuildContext context) =>
      localized(context, en: 'Successful Payment', ar: 'دفع ناجح');

  static String paymentTimedOut(BuildContext context) => localized(
        context,
        en: 'Payment timed out. You can resend the request.',
        ar: 'انتهت مهلة الدفع. يمكنك إعادة إرسال الطلب.',
      );

  static String cancel(BuildContext context) =>
      localized(context, en: 'Cancel', ar: 'إلغاء');

  // ── Card Strings ────────────────────────────────────────
  static String addCard(BuildContext context) =>
      localized(context, en: 'Add Card', ar: 'إضافة بطاقة');

  static String cardNumber(BuildContext context) =>
      localized(context, en: 'Card Number', ar: 'رقم البطاقة');

  static String cardNumberHint(BuildContext context) =>
      localized(context, en: '1234 1234 1234 1234', ar: '1234 1234 1234 1234');

  static String expiryDate(BuildContext context) =>
      localized(context, en: 'Expiry Date', ar: 'تاريخ الانتهاء');

  static String expiryHint(BuildContext context) =>
      localized(context, en: 'MM / YY', ar: 'الشهر / السنة');

  static String cvv(BuildContext context) =>
      localized(context, en: 'CVV', ar: 'رمز الامان');

  static String nameOnCard(BuildContext context) =>
      localized(context, en: 'Cardholder name', ar: 'اسم صاحب البطاقة');

  static String nameOnCardHint(BuildContext context) => localized(
        context,
        en: 'Type the name on your card',
        ar: 'اكتب الاسم الموجود على البطاقة',
      );

  static String saveThisCard(BuildContext context) => localized(
        context,
        en: 'Save this card for future payments',
        ar: 'احفظ هذه البطاقة لعمليات الدفع القادمة',
      );

  static String payWithCard(BuildContext context) =>
      localized(context, en: 'Pay with Card', ar: 'الدفع بالبطاقة');

  static String selectCard(BuildContext context) =>
      localized(context, en: 'Select card', ar: 'اختر بطاقة');

  static String edit(BuildContext context) =>
      localized(context, en: 'Edit', ar: 'تعديل');

  static String delete(BuildContext context) =>
      localized(context, en: 'Delete', ar: 'حذف');

  static String newCard(BuildContext context) =>
      localized(context, en: 'New Card', ar: 'بطاقة جديدة');

  static String card(BuildContext context) =>
      localized(context, en: 'Card', ar: 'بطاقة');

  static String cardSubtitle(BuildContext context) => localized(
        context,
        en: 'Visa, Mastercard & more',
        ar: 'فيزا، ماستركارد والمزيد',
      );

  static String addNewCard(BuildContext context) =>
      localized(context, en: 'Add New Card', ar: 'إضافة بطاقة جديدة');

  /// [count] is the number of HIDDEN cards, not the total.
  static String viewAllCards(BuildContext context, int count) => localized(
        context,
        en: 'View $count more ${count == 1 ? 'card' : 'cards'}',
        ar: 'عرض $count ${count == 1 ? 'بطاقة أخرى' : 'بطاقات أخرى'}',
      );

  static String showLess(BuildContext context) =>
      localized(context, en: 'Show less', ar: 'عرض أقل');

  static String deleteCardFailed(BuildContext context) => localized(
        context,
        en: 'Failed to delete card. Please try again.',
        ar: 'فشل حذف البطاقة. يرجى المحاولة مرة أخرى.',
      );

  // Delete-confirm dialog body (accordion inline delete — trash and swipe)
  static String deleteCardConfirm(BuildContext context, String last4) =>
      localized(
        context,
        en: 'Delete card ending in $last4?',
        ar: 'حذف البطاقة المنتهية بـ $last4؟',
      );

  // Degraded card-section error (handler bootstrap failed)
  static String cardUnavailable(BuildContext context) => localized(
        context,
        en: 'Card payment is currently unavailable. Please try another method.',
        ar: 'الدفع بالبطاقة غير متاح حالياً. يرجى استخدام طريقة أخرى.',
      );

  // Accessibility (semantics) strings for the card accordion
  static String accordionExpanded(BuildContext context) =>
      localized(context, en: 'expanded', ar: 'موسّع');

  static String accordionCollapsed(BuildContext context) =>
      localized(context, en: 'collapsed', ar: 'مطوي');

  static String loadingSavedCards(BuildContext context) => localized(context,
      en: 'Loading saved cards', ar: 'جارٍ تحميل البطاقات المحفوظة');

  static String swipeToDelete(BuildContext context) =>
      localized(context, en: 'Swipe left to delete', ar: 'اسحب لليسار للحذف');

  static String deletingCard(BuildContext context) =>
      localized(context, en: 'Deleting card...', ar: 'جارٍ حذف البطاقة...');

  // ── Result Strings ──────────────────────────────────────
  static String paymentSuccessful(BuildContext context) =>
      localized(context, en: 'Payment Successful', ar: 'تمت عملية الدفع بنجاح');

  static String paymentFailed(BuildContext context) =>
      localized(context, en: 'Payment Failed', ar: 'فشلت عملية الدفع');

  static String transactionId(BuildContext context) =>
      localized(context, en: 'Transaction ID', ar: 'رقم المعاملة');

  static String amount(BuildContext context) =>
      localized(context, en: 'Amount', ar: 'المبلغ');

  static String done(BuildContext context) =>
      localized(context, en: 'Done', ar: 'تم');

  static String tryAgain(BuildContext context) =>
      localized(context, en: 'Try Again', ar: 'حاول مجدداً');

  // ── Validation Strings ──────────────────────────────────
  static String invalidCardNumber(BuildContext context) =>
      localized(context, en: 'Invalid card number', ar: 'رقم بطاقة غير صحيح');

  static String cardExpired(BuildContext context) =>
      localized(context, en: 'Card expired', ar: 'البطاقة منتهية الصلاحية');

  static String invalidCvv(BuildContext context) =>
      localized(context, en: 'Invalid CVV', ar: 'رمز CVV غير صحيح');

  static String nameIsRequired(BuildContext context) =>
      localized(context, en: 'Name is required', ar: 'الاسم مطلوب');

  // ── 3DS String ──────────────────────────────────────────
  static String verifyingPayment(BuildContext context) => localized(
        context,
        en: 'Verifying your payment',
        ar: 'جارٍ التحقق من الدفع',
      );

  static String verifyingPaymentTitle(BuildContext context) => localized(
        context,
        en: 'Verifying payment...',
        ar: 'جارٍ التحقق من الدفع...',
      );

  static String verifyingPaymentBody(BuildContext context) => localized(
        context,
        en: 'Please wait while we confirm your transaction.',
        ar: 'يرجى الانتظار بينما نؤكد عملية الدفع.',
      );

  static String threeDSTimeoutTitle(BuildContext context) => localized(
        context,
        en: 'Still confirming your payment',
        ar: 'ما زلنا نؤكد عملية الدفع',
      );

  static String threeDSTimeoutBody(BuildContext context) => localized(
        context,
        en: "We're still confirming your payment. Please check your payment status or payment history shortly.",
        ar: 'ما زلنا نؤكد عملية الدفع. يرجى مراجعة حالة الدفع أو سجل المدفوعات بعد قليل.',
      );

  static String paymentPendingTitle(BuildContext context) => localized(
        context,
        en: 'Payment Pending',
        ar: 'الدفع قيد المعالجة',
      );

  static String paymentPendingBody(BuildContext context) => localized(
        context,
        en: "We're still confirming your payment. You'll be notified once it's complete — please check your payment history shortly.",
        ar: 'ما زلنا نؤكد عملية الدفع. سيتم إخطارك عند اكتمالها — يرجى مراجعة سجل المدفوعات بعد قليل.',
      );

  static String iHavePaid(BuildContext context) => localized(
        context,
        en: 'I have paid',
        ar: 'لقد قمت بالدفع',
      );

  static String threeDsVerificationFailed(
    BuildContext context,
    int statusCode,
  ) =>
      localized(
        context,
        en: 'Payment verification failed (HTTP $statusCode). Please try again.',
        ar: 'فشل التحقق من الدفع (HTTP $statusCode). يرجى المحاولة مرة أخرى.',
      );

  // ── Shared Strings ──────────────────────────────────────
  static String orPayUsing(BuildContext context) =>
      localized(context, en: 'Or pay using', ar: 'أو ادفع باستخدام');

  static String saved(BuildContext context) =>
      localized(context, en: 'Saved', ar: 'محفوظة');

  static String viewMore(BuildContext context) =>
      localized(context, en: 'View more', ar: 'عرض المزيد');

  static String confirm(BuildContext context) =>
      localized(context, en: 'Confirm', ar: 'تأكيد');

  static String enterCvvFor(BuildContext context, String last4) => localized(
        context,
        en: 'Enter the CVV for card ending in $last4',
        ar: 'أدخل رمز CVV للبطاقة المنتهية بـ $last4',
      );

  static String securedByKashier(BuildContext context) =>
      localized(context, en: 'Secured by Kashier', ar: 'مؤمّن بواسطة كاشير');
}
