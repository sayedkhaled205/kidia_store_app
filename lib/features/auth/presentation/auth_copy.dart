import 'package:flutter/widgets.dart';

class AuthCopy {
  const AuthCopy._({required this.isArabic});

  factory AuthCopy.of(BuildContext context) {
    return AuthCopy._(
      isArabic: Localizations.localeOf(context).languageCode == 'ar',
    );
  }

  final bool isArabic;

  String get title => isArabic
      ? 'تسجيل الدخول / إنشاء حساب'
      : 'Sign in / Register';
  String get intro => isArabic
      ? 'اكتب بريدك الإلكتروني للمتابعة'
      : 'Enter your email address to continue';
  String get email => isArabic ? 'البريد الإلكتروني' : 'Email address';
  String get emailHint => isArabic ? 'name@example.com' : 'name@example.com';
  String get emailRequired => isArabic
      ? 'اكتب بريدًا إلكترونيًا صحيحًا'
      : 'Enter a valid email address';
  String get continueLabel => isArabic ? 'متابعة' : 'Continue';
  String get existingTitle => isArabic
      ? 'أدخل كلمة المرور'
      : 'Enter your password';
  String get existingSubtitle => isArabic
      ? 'هذا البريد مسجل بالفعل في المتجر'
      : 'This email is already registered with the store';
  String get createTitle => isArabic
      ? 'أنشئ كلمة مرور'
      : 'Create a password';
  String get createSubtitle => isArabic
      ? 'سيتم إنشاء حسابك على نفس موقع المتجر'
      : 'Your account will be created on the same store website';
  String get password => isArabic ? 'كلمة المرور' : 'Password';
  String get confirmPassword => isArabic
      ? 'تأكيد كلمة المرور'
      : 'Confirm password';
  String get passwordRequired => isArabic
      ? 'اكتب كلمة المرور'
      : 'Enter your password';
  String get passwordTooShort => isArabic
      ? 'كلمة المرور يجب ألا تقل عن 8 أحرف'
      : 'Use at least 8 characters';
  String get passwordMismatch => isArabic
      ? 'كلمتا المرور غير متطابقتين'
      : 'Passwords do not match';
  String get signIn => isArabic ? 'تسجيل الدخول' : 'Sign in';
  String get createAccount => isArabic ? 'إنشاء الحساب' : 'Create account';
  String get changeEmail => isArabic ? 'تغيير البريد' : 'Change email';
  String get forgotPassword => isArabic
      ? 'نسيت كلمة المرور؟'
      : 'Forgot password?';
  String get privacyPrefix => isArabic
      ? 'بالمتابعة أنت توافق على سياسة الخصوصية.'
      : 'By continuing, you agree to the Privacy Policy.';
  String get genericError => isArabic
      ? 'تعذر إكمال تسجيل الدخول. حاول مرة أخرى.'
      : 'Could not complete sign-in. Please try again.';
  String get passwordIncorrect => isArabic
      ? 'كلمة المرور غير صحيحة. حاول مرة أخرى.'
      : 'The password is incorrect. Please try again.';
  String get rateLimited => isArabic
      ? 'محاولات كثيرة. انتظر قليلًا ثم حاول مرة أخرى.'
      : 'Too many attempts. Wait a little and try again.';
  String get secureNotice => isArabic
      ? 'سيتم حفظ جلسة الحساب بشكل آمن على جهازك.'
      : 'Your account session is stored securely on this device.';
}
