import 'package:flutter/widgets.dart';

class AuthCopy {
  const AuthCopy._({required this.isArabic});

  factory AuthCopy.of(BuildContext context) {
    return AuthCopy._(
      isArabic: Localizations.localeOf(context).languageCode == 'ar',
    );
  }

  final bool isArabic;

  String get identifier =>
      isArabic ? 'رقم الموبايل أو البريد الإلكتروني' : 'Phone number or email';
  String get identifierIntro => isArabic
      ? 'اكتب رقم موبايلك أو بريدك الإلكتروني للمتابعة'
      : 'Enter your phone number or email to continue';
  String get identifierRequired => isArabic
      ? 'اكتب رقم موبايل أو بريد إلكتروني صحيح'
      : 'Enter a valid phone number or email';
  String get phone => isArabic ? 'رقم الموبايل' : 'Phone number';
  String get phoneRequired =>
      isArabic ? 'اكتب رقم موبايل صحيح' : 'Enter a valid phone number';
  String get internationalPhone =>
      isArabic ? 'رقم الموبايل بكود الدولة' : 'Phone number with country code';
  String get internationalPhoneRequired => isArabic
      ? 'اكتب الرقم كاملًا بكود الدولة، ويبدأ بـ +'
      : 'Enter the full phone number starting with + and the country code';
  String get chooseMethod =>
      isArabic ? 'اختار طريقة الدخول' : 'Choose how to sign in';
  String get chooseAnotherMethod =>
      isArabic ? 'اختار طريقة تانية للدخول' : 'Choose another way to sign in';
  String get otpAlternatives => isArabic
      ? 'التحقق بالرمز ما اكتملش. تقدر تستخدم طريقة تانية متاحة لحسابك، أو تحاول بالرمز تاني.'
      : 'Code verification did not finish. Use another method available for your account, or try the code again.';
  String get retryCode =>
      isArabic ? 'إعادة إدخال الرمز' : 'Enter the code again';
  String get retryOtp =>
      isArabic ? 'المحاولة برمز تحقق جديد' : 'Try a new verification code';
  String get usePassword => isArabic ? 'الدخول بكلمة المرور' : 'Use password';
  String get useOtp => isArabic ? 'الدخول برمز تحقق' : 'Use verification code';
  String get otpTitle =>
      isArabic ? 'أدخل رمز التحقق' : 'Enter verification code';
  String get otpSent =>
      isArabic ? 'بعتنا رمز التحقق على رقمك' : 'We sent a code to your phone';
  String get otpCode => isArabic ? 'رمز التحقق' : 'Verification code';
  String get otpRequired => isArabic
      ? 'اكتب رمز التحقق المكوّن من 6 أرقام'
      : 'Enter the 6-digit verification code';
  String get otpIncorrect => isArabic
      ? 'رمز التحقق غير صحيح أو انتهت صلاحيته'
      : 'The verification code is incorrect or expired';
  String get verifyCode => isArabic ? 'تأكيد الرمز' : 'Verify code';
  String get sendOtp =>
      isArabic ? 'إرسال رمز التحقق' : 'Send verification code';
  String get resendOtp => isArabic ? 'إعادة إرسال الرمز' : 'Resend code';
  String get changeIdentifier => isArabic ? 'تغيير' : 'Change';
  String get chooseAccount => isArabic ? 'اختار حسابك' : 'Choose your account';
  String get chooseAccountIntro => isArabic
      ? 'الحسابات المرتبطة ببياناتك المؤكدة'
      : 'Accounts linked to your verified details';
  String get completeAccount =>
      isArabic ? 'كمّل بيانات حسابك' : 'Complete your account';
  String get verifyPhone =>
      isArabic ? 'تأكيد رقم الموبايل' : 'Verify your phone';
  String get phoneRequiredForAccount => isArabic
      ? 'أكد رقم موبايلك لإكمال حسابك'
      : 'Verify your phone number to complete your account';
  String get name => isArabic ? 'الاسم' : 'Name';
  String get nameRequired => isArabic ? 'اكتب اسمك' : 'Enter your name';
  String get optionalEmail =>
      isArabic ? 'البريد الإلكتروني (اختياري)' : 'Email address (optional)';
  String get unavailable => isArabic
      ? 'تعذر تحميل طرق الدخول. حاول مرة أخرى.'
      : 'Could not load sign-in methods. Please try again.';
  String get retry => isArabic ? 'إعادة المحاولة' : 'Try again';
  String get cancelled => isArabic
      ? 'تم إلغاء الدخول. تقدر تحاول مرة أخرى.'
      : 'Sign-in was cancelled. You can try again.';

  String get title =>
      isArabic ? 'تسجيل الدخول أو إنشاء حساب' : 'Sign in or create an account';
  String get intro => isArabic
      ? 'اكتب بريدك الإلكتروني للمتابعة'
      : 'Enter your email address to continue';
  String get email => isArabic ? 'البريد الإلكتروني' : 'Email address';
  String get emailHint => isArabic ? 'name@example.com' : 'name@example.com';
  String get emailRequired => isArabic
      ? 'اكتب بريدًا إلكترونيًا صحيحًا'
      : 'Enter a valid email address';
  String get continueLabel => isArabic ? 'متابعة' : 'Continue';
  String get existingTitle =>
      isArabic ? 'أدخل كلمة المرور' : 'Enter your password';
  String get existingSubtitle => isArabic
      ? 'هذا البريد مسجل بالفعل في المتجر'
      : 'This email is already registered with the store';
  String get createTitle => isArabic ? 'أنشئ كلمة مرور' : 'Create a password';
  String get createSubtitle => isArabic
      ? 'اختار كلمة مرور لحسابك الجديد'
      : 'Choose a password for your new account';
  String get password => isArabic ? 'كلمة المرور' : 'Password';
  String get showPassword => isArabic ? 'إظهار كلمة المرور' : 'Show password';
  String get hidePassword => isArabic ? 'إخفاء كلمة المرور' : 'Hide password';
  String get confirmPassword =>
      isArabic ? 'تأكيد كلمة المرور' : 'Confirm password';
  String get passwordRequired =>
      isArabic ? 'اكتب كلمة المرور' : 'Enter your password';
  String get passwordTooShort => isArabic
      ? 'كلمة المرور يجب ألا تقل عن 8 أحرف'
      : 'Use at least 8 characters';
  String get passwordMismatch =>
      isArabic ? 'كلمتا المرور غير متطابقتين' : 'Passwords do not match';
  String get signIn => isArabic ? 'تسجيل الدخول' : 'Sign in';
  String get createAccount => isArabic ? 'إنشاء الحساب' : 'Create account';
  String get changeEmail => isArabic ? 'تغيير البريد' : 'Change email';
  String get forgotPassword =>
      isArabic ? 'نسيت كلمة المرور؟' : 'Forgot password?';
  String get or => isArabic ? 'أو' : 'Or';
  String get continueWithGoogle =>
      isArabic ? 'المتابعة باستخدام Google' : 'Continue with Google';
  String get continueWithFacebook =>
      isArabic ? 'المتابعة باستخدام Facebook' : 'Continue with Facebook';
  String get socialSignInError => isArabic
      ? 'تعذر فتح تسجيل الدخول. حاول مرة أخرى.'
      : 'Could not open social sign-in. Please try again.';
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
