import Flutter
import UIKit

/// Flutter plugin entry point for the Kashier SDK.
///
/// This is the ONLY file that imports Flutter.
/// Routes MethodChannel calls between Dart and native payment handlers.
/// Acts as adapter between Flutter bridge and native payment logic.
@available(iOS 14.0, *)
public class KashierFlutterSdkPlugin: NSObject, FlutterPlugin {

    private let channel: FlutterMethodChannel
    private let applePayHandler = KashierApplePayHandler()

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
        applePayHandler.delegate = self
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "kashier_flutter_sdk",
            binaryMessenger: registrar.messenger()
        )
        let instance = KashierFlutterSdkPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // MARK: - MethodChannel Handler

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "isApplePayAvailable":
            result(KashierApplePayHandler.isAvailable())

        case "presentApplePay":
            guard let args = call.arguments as? [String: Any],
                  let amount = args["amount"] as? Double,
                  let currency = args["currency"] as? String,
                  let storeName = args["storeName"] as? String,
                  let supportedNetworks = args["supportedNetworks"] as? [String],
                  let merchantId = args["merchantId"] as? String else {
                result(FlutterError(
                    code: "INVALID_ARGUMENTS",
                    message: "Missing required arguments for presentApplePay",
                    details: nil
                ))
                return
            }

            applePayHandler.presentApplePay(
                amount: amount,
                currency: currency,
                storeName: storeName,
                supportedNetworks: supportedNetworks,
                merchantId: merchantId
            )
            result(nil)

        case "completePaymentAuthorization":
            let success = (call.arguments as? [String: Any])?["success"] as? Bool ?? false
            applePayHandler.completePaymentAuthorization(success: success)
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - KashierApplePayDelegate

@available(iOS 14.0, *)
extension KashierFlutterSdkPlugin: KashierApplePayDelegate {

    func applePayDidAuthorizePayment(token: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod("onTokenReceived", arguments: token)
        }
    }

    func applePayDidFailWithError(code: String) {
        DispatchQueue.main.async { [weak self] in
            self?.channel.invokeMethod(
                "onPaymentError",
                arguments: ["errorCode": code]
            )
        }
    }
}
