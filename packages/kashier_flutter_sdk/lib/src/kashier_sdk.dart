import 'package:meta/meta.dart';

import '../models/kashier_language.dart';
import '../models/kashier_mode.dart';
import '../models/kashier_payment_error.dart';
import '../models/kashier_payment_pending.dart';
import '../models/kashier_payment_result.dart';
import 'kashier_api.dart';
import 'kashier_bridge.dart';
import 'kashier_connectivity.dart';
import 'models/kashier_session.dart';
import 'payment_handler/apple_pay/kashier_apple_pay_handler.dart';
import 'payment_handler/card/kashier_card_handler.dart';
import 'payment_handler/kashier_payment_handler.dart';
import 'payment_handler/wallet/kashier_wallet_handler.dart';
import 'ui/kashier_payment_sheet.dart';

/// Main entry point for the Kashier Payment SDK.
///
/// Initialize once at app startup, then use [startPayment] to begin
/// a payment flow. The SDK automatically selects the appropriate
/// payment method based on the session configuration and device capabilities.
///
/// Your app must be wrapped with [KashierPaymentProvider]:
///
/// ```dart
/// void main() {
///   runApp(
///     KashierPaymentProvider(
///       child: MaterialApp(home: MyApp()),
///     ),
///   );
/// }
/// ```
///
/// Then initialize and start payments:
///
/// ```dart
/// KashierSDK.initialize(mode: KashierMode.test);
///
/// KashierSDK.startPayment(
///   sessionId: 'sess_123',
///   onSuccess: (result) => showSuccessScreen(result.status),
///   onFailure: (error) => showErrorMessage(error.message),
/// );
/// ```
class KashierSDK {
  KashierSDK._();

  static KashierMode? _mode;
  static KashierLanguage _language = KashierLanguage.en;
  static KashierApi? _api;
  static KashierBridge? _bridge;
  static String? _appleMerchantId;
  static final Map<String, KashierPaymentHandler Function()> _handlerFactories =
      {};

  /// Whether the SDK has been initialized.
  static bool get isInitialized => _mode != null;

  /// The current mode (test or live). Null if not yet initialized.
  static KashierMode? get mode => _mode;

  /// The current display language for the SDK UI. Defaults to English.
  static KashierLanguage get language => _language;

  /// Initializes the Kashier SDK.
  ///
  /// Must be called once before any other SDK methods. Call again whenever
  /// the host app's language changes so the SDK UI stays in sync.
  ///
  /// [mode] controls which Kashier API environment is used (test or live).
  /// [language] sets the language used to render the SDK's payment sheets.
  /// Defaults to [KashierLanguage.en] when omitted.
  /// [appleMerchantId] is the merchant's own Apple Pay Merchant ID
  /// (e.g. `merchant.com.yourcompany.app`). Required only to enable Apple Pay;
  /// it must match the Merchant ID configured in the app's Xcode entitlement.
  /// When omitted, Apple Pay is not offered.
  static void initialize({
    required KashierMode mode,
    KashierLanguage language = KashierLanguage.en,
    String? appleMerchantId,
  }) {
    // Clean up previous instance if re-initializing.
    _api?.dispose();
    _handlerFactories.clear();

    _mode = mode;
    _language = language;
    _appleMerchantId = appleMerchantId;
    _api = KashierApi(mode: mode);
    _bridge = KashierBridge();

    // Begin observing network link status. Pre-flight checks inside
    // [KashierApi] rely on this to fail fast when the device is offline.
    KashierConnectivity.instance.start();

    // Register payment method factories.
    // Each factory creates a fresh handler instance — handlers are stateful
    // (they hold callbacks, polling timers, etc.) so they must not be shared.
    _registerHandler(
      'applePay',
      () => KashierApplePayHandler(
        api: _api!,
        bridge: _bridge!,
        appleMerchantId: _appleMerchantId,
      ),
    );
    _registerHandler(
      'wallet',
      () => KashierWalletHandler(api: _api!),
    );
    _registerHandler(
      'card',
      () => KashierCardHandler(api: _api!),
    );
  }

  /// Registers a handler factory for a payment method.
  ///
  /// Called during [initialize]. New payment methods (Card, BNPL, InstaPay)
  /// only need to add a registration call here.
  static void _registerHandler(
    String methodId,
    KashierPaymentHandler Function() factory,
  ) {
    _handlerFactories[methodId] = factory;
  }

  /// Creates a new handler instance for the given payment method.
  ///
  /// Returns a typed handler so callers can access method-specific APIs
  /// (e.g., [KashierWalletHandler.initiatePayment]).
  ///
  /// Returns `null` if the method is not registered.
  @internal
  static T? createHandler<T extends KashierPaymentHandler>(String methodId) {
    final factory = _handlerFactories[methodId];
    if (factory == null) return null;
    return factory() as T;
  }

  /// Returns the method IDs that are registered, allowed by the session,
  /// and available on this device.
  ///
  /// Used by the payment sheet to determine which methods to show.
  /// A method must pass all three checks:
  /// 1. Registered in the factory (known to the SDK)
  /// 2. Allowed by the session config (or session allows all methods)
  /// 3. Available on the device (e.g., Apple Pay requires PassKit + cards)
  static Future<List<String>> _getAvailableMethods(
    KashierSession session,
  ) async {
    final available = <String>[];
    final allowed = session.allowedMethods;
    for (final methodId in _handlerFactories.keys) {
      // Empty list = all methods allowed (field absent or empty string).
      if (allowed.isNotEmpty && !_isMethodAllowed(methodId, allowed)) {
        continue;
      }
      // Check device capability.
      // If the check throws (e.g., no native plugin on this platform),
      // treat the method as unavailable.
      final handler = _handlerFactories[methodId]!();
      try {
        if (await handler.isAvailable()) {
          available.add(methodId);
        }
      } catch (_) {
        // Method not available on this platform.
      }
    }
    return available;
  }

  /// Checks whether a payment method is allowed by the session's allowedMethods.
  ///
  /// Apple Pay is a card-based method, so "card" or "applePay" both unlock it.
  /// Wallet requires an explicit "wallet" entry.
  static bool _isMethodAllowed(String methodId, List<String> allowed) {
    if (methodId == 'applePay') {
      return allowed.contains('applePay') || allowed.contains('card');
    }
    return allowed.contains(methodId);
  }

  /// Starts a payment flow for the given session.
  ///
  /// The SDK fetches session details from the Kashier backend, determines
  /// available payment methods, and presents a method selection sheet
  /// on the SDK's own overlay (provided by [KashierPaymentProvider]).
  ///
  /// No [BuildContext] is needed — the SDK manages its own UI layer.
  ///
  /// [sessionId] is the payment session ID from your backend.
  /// [onSuccess] is called when the payment completes successfully.
  /// [onFailure] is called when the payment fails or is cancelled.
  /// [onPending] is optionally called when reconcile polling exhausts while the
  /// payment is still settling — terminal for both card and wallet, with no
  /// later onSuccess/onFailure. For card it fires after 3DS reconcile exhaustion;
  /// for wallet it fires after the 5-minute poll exhausts still pending and the
  /// customer taps "I have paid". Confirm final settlement via webhook/backend.
  /// Apple Pay never fires onPending.
  static Future<void> startPayment({
    required String sessionId,
    required void Function(KashierPaymentResult result) onSuccess,
    required void Function(KashierPaymentError error) onFailure,
    void Function(KashierPaymentPending pending)? onPending,
  }) async {
    if (!isInitialized) {
      onFailure(KashierPaymentError.fromCode(
        KashierErrorCode.unknownError,
        message:
            'KashierSDK.initialize() must be called before startPayment().',
      ));
      return;
    }

    try {
      // Fetch session details from Kashier API.
      final session = await _api!.getSession(sessionId);

      // Determine which payment methods are available.
      final availableMethods = await _getAvailableMethods(session);

      // Show the payment sheet on the SDK overlay.
      showKashierPaymentSheet(
        session: session,
        availableMethods: availableMethods,
        onSuccess: onSuccess,
        onFailure: onFailure,
        onPending: onPending,
      );
    } on KashierPaymentError catch (e) {
      onFailure(e);
    } catch (e) {
      onFailure(KashierPaymentError.fromCode(
        KashierErrorCode.unknownError,
        details: e,
      ));
    }
  }

  /// Checks whether Apple Pay is available on this device.
  ///
  /// Returns `true` if the device supports Apple Pay and has at least
  /// one configured payment card with a supported network.
  static Future<bool> isApplePayAvailable() async {
    if (!isInitialized) return false;

    final handler = createHandler<KashierApplePayHandler>('applePay');
    if (handler == null) return false;

    return handler.isAvailable();
  }
}
