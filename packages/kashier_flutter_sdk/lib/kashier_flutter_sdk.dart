/// Kashier Flutter SDK — accept payments in your Flutter app.
///
/// Supports Apple Pay (iOS) and Wallet (Vodafone Cash & more) with a
/// pre-built payment UI. Additional methods (Card, BNPL) coming soon.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:kashier_flutter_sdk/kashier_flutter_sdk.dart';
///
/// // 1. Initialize once (e.g., in main)
/// KashierSDK.initialize(mode: KashierMode.live);
///
/// // 2. Start a payment (sessionId comes from your backend)
/// KashierSDK.startPayment(
///   sessionId: 'sess_abc123',
///   onSuccess: (result) => showSuccessScreen(result.status),
///   onFailure: (error) => showErrorMessage(error.message),
///   onPending: (pending) => showPendingScreen(pending.orderId),
/// );
/// ```
///
/// See [KashierSDK] for the full API, [KashierPaymentError] for error codes,
/// and [KashierPaymentResult] for success data.
library;

// Public API
export 'src/kashier_sdk.dart';

// Public models
export 'models/kashier_language.dart';
export 'models/kashier_mode.dart';
export 'models/kashier_payment_error.dart';
export 'models/kashier_payment_pending.dart';
export 'models/kashier_payment_result.dart';
export 'models/kashier_wallet_provider.dart';

// Public widgets
export 'src/payment_handler/apple_pay/kashier_apple_pay_button.dart';
export 'src/ui/kashier_payment_provider.dart';
