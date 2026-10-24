import Foundation
import PassKit

// MARK: - Protocol for cross-platform reuse

/// Protocol for receiving Apple Pay payment events.
///
/// Implemented by the Flutter plugin adapter (`KashierFlutterSdkPlugin`),
/// but can also be implemented by React Native or Native iOS adapters
/// without any changes to this file.
@available(iOS 14.0, *)
protocol KashierApplePayDelegate: AnyObject {
    /// Called when Apple Pay returns an encrypted payment token. (Cross #2 UP)
    func applePayDidAuthorizePayment(token: [String: Any])

    /// Called when a payment error occurs.
    func applePayDidFailWithError(code: String)
}

// MARK: - Apple Pay Handler

/// Handles Apple Pay payment authorization and delegate callbacks.
///
/// This class manages the PKPaymentAuthorizationController lifecycle:
/// presenting the payment sheet and extracting the encrypted payment token.
///
/// Native in-app Apple Pay needs no merchant-validation handshake — the app's
/// signed Apple Pay entitlement establishes merchant trust. The merchant
/// identifier is supplied per payment by the caller (the merchant's own ID).
///
/// Designed for direct reuse in React Native SDK and Native iOS SDK:
/// - Zero Flutter imports
/// - Communicates via `KashierApplePayDelegate` protocol
/// - All Apple Pay logic is self-contained in this file
@available(iOS 14.0, *)
class KashierApplePayHandler: NSObject {

    // MARK: - Delegate

    /// Delegate for receiving payment events. Use weak to avoid retain cycles.
    weak var delegate: KashierApplePayDelegate?

    // MARK: - Private State

    private var paymentController: PKPaymentAuthorizationController?
    private var paymentAuthorizationCompletion: ((PKPaymentAuthorizationResult) -> Void)?

    /// Tracks whether a token was authorized (to distinguish cancel from completion).
    private var didAuthorizePayment = false

    // MARK: - Public Methods

    /// Checks whether Apple Pay is available on this device with supported networks.
    static func isAvailable(supportedNetworks: [String]? = nil) -> Bool {
        let canMake = PKPaymentAuthorizationController.canMakePayments()
        guard canMake else {
            return false
        }

        let networkNames = supportedNetworks ?? ["visa", "mastercard", "meeza"]
        let networks = resolveNetworks(networkNames)
        return PKPaymentAuthorizationController.canMakePayments(usingNetworks: networks)
    }

    /// Presents the Apple Pay payment sheet. (Cross #1 DOWN)
    ///
    /// [merchantId] is the merchant's own Apple Pay Merchant ID, supplied by
    /// the Dart layer (from `KashierSDK.initialize(appleMerchantId:)`).
    func presentApplePay(
        amount: Double,
        currency: String,
        storeName: String,
        supportedNetworks: [String],
        merchantId: String
    ) {
        // Reset state for new payment.
        didAuthorizePayment = false
        paymentAuthorizationCompletion = nil

        let networks = KashierApplePayHandler.resolveNetworks(supportedNetworks)

        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantId
        request.supportedNetworks = networks
        request.merchantCapabilities = .capability3DS
        request.countryCode = "EG"
        request.currencyCode = currency

        let paymentItem = PKPaymentSummaryItem(
            label: storeName,
            amount: NSDecimalNumber(value: amount)
        )
        request.paymentSummaryItems = [paymentItem]

        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self
        self.paymentController = controller

        DispatchQueue.main.async { [weak self] in
            controller.present { presented in
                if !presented {
                    self?.delegate?.applePayDidFailWithError(code: "APPLE_PAY_NOT_AVAILABLE")
                }
            }
        }
    }

    /// Called by the Dart layer after token processing to finalize the payment sheet.
    func completePaymentAuthorization(success: Bool) {
        let status: PKPaymentAuthorizationStatus = success ? .success : .failure
        paymentAuthorizationCompletion?(PKPaymentAuthorizationResult(status: status, errors: nil))
        paymentAuthorizationCompletion = nil
    }

    // MARK: - Private Helpers

    /// Converts string network names to PKPaymentNetwork values.
    private static func resolveNetworks(_ names: [String]) -> [PKPaymentNetwork] {
        return names.compactMap { resolveNetwork($0.lowercased()) }
    }

    /// Maps a single network name string to a PKPaymentNetwork.
    private static func resolveNetwork(_ name: String) -> PKPaymentNetwork? {
        switch name {
        case "visa":
            return .visa
        case "mastercard":
            return .masterCard
        case "amex":
            return .amex
        case "meeza":
            return PKPaymentNetwork(rawValue: "Meeza")
        default:
            return nil
        }
    }

    /// Maps PKPaymentMethodType to the string expected by the Kashier API.
    private static func paymentMethodTypeString(_ type: PKPaymentMethodType) -> String {
        switch type {
        case .debit:
            return "debit"
        case .credit:
            return "credit"
        case .prepaid:
            return "prepaid"
        case .store:
            return "store"
        case .eMoney:
            return "eMoney"
        default:
            return "unknown"
        }
    }

    /// Cleans up controller references.
    private func cleanup() {
        paymentController = nil
        paymentAuthorizationCompletion = nil
        didAuthorizePayment = false
    }
}

// MARK: - PKPaymentAuthorizationControllerDelegate

@available(iOS 14.0, *)
extension KashierApplePayHandler: PKPaymentAuthorizationControllerDelegate {

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        didAuthorizePayment = true
        paymentAuthorizationCompletion = completion

        // Serialize the payment token to a dictionary
        let tokenData = payment.token.paymentData

        guard let tokenJSON = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any] else {
            completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
            delegate?.applePayDidFailWithError(code: "TOKEN_PROCESSING_FAILED")
            return
        }

        // Build the full token payload including payment method info
        let tokenPayload: [String: Any] = [
            "paymentData": tokenJSON,
            "paymentMethod": [
                "displayName": payment.token.paymentMethod.displayName ?? "",
                "network": payment.token.paymentMethod.network?.rawValue ?? "",
                "type": KashierApplePayHandler.paymentMethodTypeString(payment.token.paymentMethod.type),
            ],
            "transactionIdentifier": payment.token.transactionIdentifier,
        ]

        delegate?.applePayDidAuthorizePayment(token: tokenPayload)
    }

    func paymentAuthorizationControllerDidFinish(
        _ controller: PKPaymentAuthorizationController
    ) {
        // Capture state before any async work — delegate callbacks must fire
        // before cleanup nils out references.
        let wasAuthorized = didAuthorizePayment

        if !wasAuthorized {
            // Non-authorized dismissals are treated as user cancellation:
            //   • User tapped Cancel.
            //   • Simulator / missing cert where the sheet can't authorize.
            // APPLE_PAY_CONFIG_ERROR is already reported by present() failing
            // (see presentApplePay), so we don't duplicate it here.
            delegate?.applePayDidFailWithError(code: "USER_CANCELLED")
        }

        DispatchQueue.main.async { [weak self] in
            controller.dismiss {
                self?.cleanup()
            }
        }
    }
}
