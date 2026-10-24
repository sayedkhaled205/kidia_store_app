class ThreeDSChallengeDetector {
  static bool isOtpSubmitMessage(String message) {
    return message.contains('otpvalue') ||
        message.contains('validAuthentication') ||
        message.contains('enterOTP');
  }

  /// Signals that the ACS re-rendered the OTP page after a submit, which
  /// means the OTP was wrong. Covers multiple ACS variants:
  /// - Banque Misr (MPGS/JSF): partial update targeting the OTP form.
  /// - NBE (Wibmo Arabic UI): full-page reload emitting page-init debug logs.
  /// Correct-OTP paths navigate away instead of re-rendering, so these
  /// markers never appear on a success flow.
  static bool indicatesOtpFormReRender(String message) {
    if (message.contains('applied updates') &&
        (message.contains('customerAuthForm') ||
            message.contains('authenticationOtpForm') ||
            message.contains('otpAuthForm'))) {
      return true;
    }
    if (message.contains('Arabic Content') ||
        message.contains('inside arabic')) {
      return true;
    }
    return false;
  }

  /// True when a console message shows the ACS challenge / OTP screen is
  /// being presented to the user. Covers CIB/Wibmo, Banque Misr/MPGS, NBE
  /// and similar ACS variants that deliver the challenge into the FEP verify
  /// page over Socket.IO without changing the page URL.
  ///
  /// These markers only appear once a real challenge renders — the
  /// frictionless verify-page-stuck path goes silent after the Socket.IO
  /// connect, so this never fires there.
  static bool indicatesChallengePresented(String message) {
    return
        // CIB / Wibmo — challenge injected over Socket.IO into the verify page.
        message.contains('challenge Info Text') ||
            message.contains('challengeInfoText') ||
            message.contains('Masked Dot Number') ||
            message.contains('enableErrorDiv') ||
            message.contains('enterOTP') ||
            message.contains('otpvalue') ||
            message.contains('validAuthentication') ||
            message.contains('challengeWindow') ||
            message.contains('challenge-container') ||
            // Banque Misr / MPGS — verify page full-submits into a cross-origin
            // ACS OTP iframe (no main-frame navigation, no Socket.IO markers).
            message.contains('otpAuthPage') ||
            message.contains('acsauthentication') ||
            message.contains('otpAuthForm') ||
            message.contains('customerAuthForm') ||
            message.contains('authenticationOtpForm') ||
            message.contains('3ds.banquemisr.com') ||
            // Generic ACS hand-off the verify page logs for any provider.
            message.contains('full submit to') ||
            message.contains('/acs/');
  }

  static bool hasInvalidOtpText(String text) {
    final normalized = text.toLowerCase();
    return normalized.contains('incorrect') ||
        normalized.contains('invalid otp') ||
        normalized.contains('invalid code') ||
        normalized.contains('wrong otp') ||
        normalized.contains('wrong code') ||
        text.contains('غير صحيح') ||
        text.contains('غير صالح') ||
        text.contains('خاطئ') ||
        text.contains('خطأ');
  }
}
