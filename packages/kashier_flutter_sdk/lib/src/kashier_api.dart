import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/kashier_mode.dart';
import '../models/kashier_payment_error.dart';
import '../models/kashier_payment_result.dart';
import 'kashier_connectivity.dart';
import 'models/card_payment_response.dart';
import 'models/kashier_card.dart';
import 'models/kashier_session.dart';
import 'models/wallet_initiate_response.dart';

/// Handles all HTTP communication with the Kashier backend.
///
/// This class is internal and not exported to merchants.
class KashierApi {
  final KashierMode _mode;
  final http.Client _client;
  final KashierConnectivityChecker _connectivity;

  KashierApi({
    required KashierMode mode,
    http.Client? client,
    KashierConnectivityChecker? connectivity,
  })  : _mode = mode,
        _client = client ?? http.Client(),
        _connectivity = connectivity ?? KashierConnectivity.instance;

  /// Throws [KashierErrorCode.networkError] when the device has no route to
  /// the internet. Called at the top of every HTTP method so users see a
  /// clear "check your connection" message instead of waiting for a socket
  /// timeout when they tap Pay offline.
  Future<void> _ensureOnline() async {
    final online = await _connectivity.hasInternet();
    if (online) return;
    throw KashierPaymentError.fromCode(KashierErrorCode.networkError);
  }

  /// Fetches session details from the Kashier API.
  ///
  /// GET /v3/payment/sessions/:sessionId
  Future<KashierSession> getSession(String sessionId) async {
    await _ensureOnline();
    final url = Uri.parse('${_mode.baseUrl}/v3/payment/sessions/$sessionId');


    final http.Response response;
    try {
      response = await _client.get(url);
    } catch (e) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.networkError,
        details: e,
      );
    }

    final body = _decodeResponse(response);


    if (response.statusCode == 404) {
      throw KashierPaymentError.fromCode(KashierErrorCode.sessionNotFound);
    }

    if (response.statusCode == 410) {
      throw KashierPaymentError.fromCode(KashierErrorCode.sessionExpired);
    }

    if (response.statusCode != 200) {
      final messages = body['messages'] as Map<String, dynamic>?;
      throw KashierPaymentError.fromCode(
        KashierErrorCode.unknownError,
        message: messages?['en'] as String? ??
            'Failed to fetch session: HTTP ${response.statusCode}',
        messageAr: messages?['ar'] as String?,
        details: body,
      );
    }

    try {
      final session = KashierSession.fromJson(body, sessionId);
      return session;
    } catch (e) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.unknownError,
        message: 'Failed to parse session response.',
        details: 'Response: $body\nError: $e',
      );
    }
  }

  /// Builds the shared order request body for /v3/orders.
  ///
  /// Contains all fields common to every payment method: session, order,
  /// customer, reconciliation, device, interactionSource, newPaymentUI.
  /// Callers add `apiOperation` and `paymentMethod` before calling.
  Map<String, dynamic> _buildOrderBody({
    required KashierSession session,
    required String apiOperation,
    required Map<String, dynamic> paymentMethod,
  }) {
    final body = <String, dynamic>{
      'apiOperation': apiOperation,
      'paymentMethod': paymentMethod,
      'sessionId': session.sessionId,
      'merchantId': session.merchantId,
      'order': {
        'reference': session.orderReference,
        'amount': session.rawAmount,
        'currency': session.currency,
        if (session.description != null) 'description': session.description,
        if (session.rawOriginalAmount != null)
          'originalAmount': session.rawOriginalAmount,
      },
      'device': {
        'browser': 'Flutter Native',
        'browserDetails': {
          'javaEnabled': false,
          'language': 'en-US',
          'screenHeight': 800,
          'screenWidth': 400,
          'timeZone': DateTime.now().timeZoneOffset.inMinutes * -1,
          'colorDepth': 24,
          '3DSecureChallengeWindowSize': '390_X_400',
        },
      },
      'interactionSource': session.interactionSource,
      'newPaymentUI': true,
      'timestamp': -2,
    };

    // Include customer only if session has customer data.
    if (session.customer != null && session.customer!.hasData) {
      body['customer'] = session.customer!.toOrderJson();
    }

    // Include reconciliation only if both URLs exist.
    if (session.serverWebhook != null && session.merchantRedirect != null) {
      body['reconciliation'] = <String, dynamic>{
        'webhookUrl': session.serverWebhook,
        'merchantRedirect': session.merchantRedirect,
      };
    }

    return body;
  }

  /// Builds the reconciliation object for PAY (card) requests.
  ///
  /// `redirect: true` is always present. `merchantRedirect` and `webhookUrl`
  /// are included only when set on the session.
  Map<String, dynamic> _buildPayReconciliation(KashierSession session) {
    final reconciliation = <String, dynamic>{'redirect': true};
    if (session.merchantRedirect != null) {
      reconciliation['merchantRedirect'] = session.merchantRedirect;
    }
    if (session.serverWebhook != null) {
      reconciliation['webhookUrl'] = session.serverWebhook;
    }
    return reconciliation;
  }

  /// Processes the Apple Pay token by creating an order via the Kashier FEP.
  ///
  /// POST /v3/orders on fep.kashier.io
  Future<KashierPaymentResult> processApplePayToken({
    required KashierSession session,
    required Map<String, dynamic> applePayToken,
  }) async {
    await _ensureOnline();
    final url = Uri.parse('${_mode.fepBaseUrl}/v3/orders');

    final body = _buildOrderBody(
      session: session,
      apiOperation: 'PAY',
      paymentMethod: {
        'type': 'CARD',
        'card': {
          'applePay': {'token': applePayToken},
          'save': false,
        },
      },
    );


    final http.Response response;
    try {
      response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'kashier-hash': session.hash,
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.networkError,
        details: e,
      );
    }

    final responseBody = _decodeResponse(response);
    final apiStatus = responseBody['status'] as String?;


    // Any non-200 status code is an error (403 forbidden, 500 server error, etc.).
    if (response.statusCode != 200) {
      throw KashierPaymentError.fromApiResponse(
        responseBody,
        statusCode: response.statusCode,
      );
    }

    // 200 but status=FAILURE means issuer declined the payment.
    if (apiStatus == 'FAILURE') {
      throw KashierPaymentError.fromApiResponse(
        responseBody,
        statusCode: response.statusCode,
      );
    }

    return KashierPaymentResult.fromApiResponse(
      responseBody,
      sessionId: session.sessionId,
    );
  }

  /// Initiates a wallet payment via the INITIATE_R2P API.
  ///
  /// POST /v3/orders on fep.kashier.io
  Future<WalletInitiateResponse> initiateWalletPayment({
    required KashierSession session,
    required String phoneNumber,
  }) async {
    await _ensureOnline();
    final url = Uri.parse('${_mode.fepBaseUrl}/v3/orders');

    final body = _buildOrderBody(
      session: session,
      apiOperation: 'INITIATE_R2P',
      paymentMethod: {
        'type': 'WALLET',
        'wallet': {'mobilePhone': phoneNumber},
      },
    );


    final http.Response response;
    try {
      response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'kashier-hash': session.hash,
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.networkError,
        details: e,
      );
    }

    final responseBody = _decodeResponse(response);


    if (response.statusCode != 200) {
      // Try to extract human-readable messages from the backend response.
      final messages = responseBody['messages'] as Map<String, dynamic>?;
      final messageEn = messages?['en'] as String?;
      final messageAr = messages?['ar'] as String?;
      throw KashierPaymentError.fromCode(
        KashierErrorCode.walletInitFailed,
        message: messageEn ?? 'Failed to initiate wallet payment.',
        messageAr: messageAr,
        details: responseBody,
      );
    }

    final apiStatus = responseBody['status'] as String?;
    if (apiStatus == 'FAILURE') {
      throw KashierPaymentError.fromApiResponse(
        responseBody,
        statusCode: response.statusCode,
      );
    }

    return WalletInitiateResponse.fromApiResponse(responseBody);
  }

  /// Checks the status of a wallet payment via the RECONCILE API.
  ///
  /// PUT /v3/orders/:orderId on fep.kashier.io
  Future<WalletReconcileResponse> reconcilePayment({
    required String orderId,
  }) async {
    await _ensureOnline();
    final url = Uri.parse('${_mode.fepBaseUrl}/v3/orders/$orderId');


    final http.Response response;
    try {
      response = await _client.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'apiOperation': 'RECONCILE'}),
      );
    } catch (e) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.networkError,
        details: e,
      );
    }

    final responseBody = _decodeResponse(response);


    if (response.statusCode != 200) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.unknownError,
        message: 'Payment status check failed: HTTP ${response.statusCode}',
        details: responseBody,
      );
    }

    return WalletReconcileResponse.fromApiResponse(responseBody);
  }

  /// Checks the status of a card 3DS payment via the RECONCILE API.
  ///
  /// PUT /v3/orders/:orderId on fep.kashier.io with apiOperation=RECONCILE.
  ///
  /// The /v3/orders/device/:orderId path is the 3DS device-init endpoint,
  /// used BEFORE the challenge to obtain the redirect HTML. Calling it a
  /// second time after OTP completes returns HTTP 400 because the order
  /// is past that stage. The generic /v3/orders/:orderId RECONCILE path
  /// returns the current order status regardless of payment rail.
  Future<WalletReconcileResponse> reconcileCardPayment({
    required String orderId,
  }) async {
    await _ensureOnline();
    final url = Uri.parse('${_mode.fepBaseUrl}/v3/orders/$orderId');


    final http.Response response;
    try {
      response = await _client.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'apiOperation': 'RECONCILE'}),
      );
    } catch (e) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.networkError,
        details: e,
      );
    }

    final responseBody = _decodeResponse(response);


    if (_isCardReconcileTransactionNotFound(
      statusCode: response.statusCode,
      body: responseBody,
    )) {
      final messages = responseBody['messages'] as Map<String, dynamic>?;
      return WalletReconcileResponse(
        result: 'PENDING',
        status: 'NOT_FOUND',
        messageEn: messages?['en'] as String? ?? 'Transaction not found',
        messageAr: messages?['ar'] as String? ?? '',
        rawBody: responseBody,
      );
    }

    if (_isCardReconcileTerminalPayload(responseBody)) {
      return WalletReconcileResponse.fromApiResponse(responseBody);
    }

    if (response.statusCode != 200) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.unknownError,
        message: 'Payment status check failed: HTTP ${response.statusCode}',
        details: responseBody,
      );
    }

    return WalletReconcileResponse.fromApiResponse(responseBody);
  }

  bool _isCardReconcileTransactionNotFound({
    required int statusCode,
    required Map<String, dynamic> body,
  }) {
    if (statusCode != 404) return false;

    final messages = body['messages'] as Map<String, dynamic>?;
    final response = body['response'] as Map<String, dynamic>?;
    final transactionMessages =
        response?['transactionResponseMessage'] as Map<String, dynamic>?;
    final candidates = [
      messages?['en'],
      messages?['ar'],
      response?['message'],
      transactionMessages?['en'],
      transactionMessages?['ar'],
    ].whereType<String>().map((value) => value.toLowerCase()).toList();

    return candidates.any(
      (message) =>
          message.contains('transaction not found') ||
          message.contains('المعاملة غير موجودة'),
    );
  }

  bool _isCardReconcileTerminalPayload(Map<String, dynamic> body) {
    final response = body['response'] as Map<String, dynamic>?;
    if (response == null || response.isEmpty) return false;

    const terminalResults = {'SUCCESS', 'FAILURE'};
    const terminalStatuses = {
      'SUCCESS',
      'CAPTURED',
      'FAILED',
      'FAILURE',
      'DECLINED',
      'EXPIRED',
      'VOIDED',
    };

    final result = response['result'] as String?;
    final status = response['status'] as String?;

    return terminalResults.contains(result) ||
        terminalStatuses.contains(status);
  }

  /// Fetches saved cards for the customer.
  ///
  /// GET {fepBaseUrl}/v3/cards/customer
  ///   ?customerReference=...&merchantId=...&order={"currency":"EGP","amount":"100","reference":"order12345"}
  ///
  /// The `order` query param is a JSON-encoded object required by the backend
  /// to filter saved cards by the current order context (currency-specific
  /// card eligibility). Returns an empty list on FAILURE status (not an error).
  Future<List<KashierCard>> getSavedCards({
    required KashierSession session,
  }) async {
    await _ensureOnline();
    final customerRef = session.customer?.reference ?? '';
    final orderJson = jsonEncode({
      'currency': session.currency,
      'amount': session.rawAmount.toString(),
      'reference': session.orderReference,
    });
    final url = Uri.parse('${_mode.fepBaseUrl}/v3/cards/customer').replace(
      queryParameters: {
        'customerReference': customerRef,
        'merchantId': session.merchantId,
        'order': orderJson,
      },
    );


    final http.Response response;
    try {
      response = await _client.get(
        url,
        headers: {'Kashier-Hash': session.hash},
      );
    } catch (e) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.cardRetrievalFailed,
        details: e,
      );
    }

    final body = _decodeResponse(response);

    if (response.statusCode != 200) {
      return <KashierCard>[];
    }

    final apiStatus = body['status'] as String?;
    if (apiStatus == 'FAILURE') {
      return <KashierCard>[];
    }

    // Real response shape:
    //   { status: "SUCCESS",
    //     response: { paymentMethods: [ { type: "CARD", card: {...} }, ... ] } }
    // We keep only CARD-typed entries and hand the nested `card` object to
    // KashierCard.fromJson.
    final responseMap = body['response'] as Map<String, dynamic>? ?? {};
    final paymentMethods = responseMap['paymentMethods'] as List? ?? [];
    final result = paymentMethods
        .whereType<Map<String, dynamic>>()
        .where((pm) => (pm['type'] as String?)?.toUpperCase() == 'CARD')
        .map((pm) => pm['card'])
        .whereType<Map<String, dynamic>>()
        .map(KashierCard.fromJson)
        .where((c) => c.cardToken.isNotEmpty)
        .toList();

    return result;
  }

  /// Deletes a saved card token.
  ///
  /// DELETE {fepBaseUrl}/v3/cards/tokens/{cardToken}
  ///   ?customerReference=...&merchantId=...&order={"currency":"EGP","amount":"100","reference":"..."}
  Future<void> deleteSavedCard({
    required KashierSession session,
    required String cardToken,
  }) async {
    await _ensureOnline();
    final customerRef = session.customer?.reference ?? '';
    final orderJson = jsonEncode({
      'currency': session.currency,
      'amount': session.rawAmount.toString(),
      'reference': session.orderReference,
    });
    final url = Uri.parse(
      '${_mode.fepBaseUrl}/v3/cards/tokens/$cardToken',
    ).replace(
      queryParameters: {
        'customerReference': customerRef,
        'merchantId': session.merchantId,
        'order': orderJson,
      },
    );

    // Never log the full URL — the card token is a path segment.

    final http.Response response;
    try {
      response = await _client.delete(
        url,
        headers: {'kashier-hash': session.hash},
      );
    } catch (e) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.cardDeletionFailed,
        details: e,
      );
    }

    final body = _decodeResponse(response);

    if (response.statusCode != 200) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.cardDeletionFailed,
        message: 'Failed to delete card: HTTP ${response.statusCode}',
        details: body,
      );
    }

  }

  /// Pays with a new card.
  ///
  /// POST {fepBaseUrl}/v3/orders with PAY + CARD type.
  /// Returns a [CardPaymentResponse] — the handler interprets the status.
  Future<CardPaymentResponse> payWithNewCard({
    required KashierSession session,
    required KashierCardInput card,
  }) async {
    await _ensureOnline();
    final url = Uri.parse('${_mode.fepBaseUrl}/v3/orders');

    final body = _buildOrderBody(
      session: session,
      apiOperation: 'PAY',
      paymentMethod: {
        'type': 'CARD',
        'card': {
          'number': card.cardNumber,
          'nameOnCard': card.nameOnCard,
          'expiry': {'month': card.expiryMonth, 'year': card.expiryYear},
          'securityCode': card.cvv,
          'enable3DS': session.enable3DS ?? true,
          // Only save if customer exists — backend requires customer to store token.
          'save': card.saveCard &&
              session.customer != null &&
              session.customer!.hasData,
        },
      },
    );

    body['reconciliation'] = _buildPayReconciliation(session);
    // newPaymentUI is deliberately KEPT for PAY: without it the live backend
    // returns the legacy /3dsRedirect URL (methodUrl=undefined) whose page is
    // dead; with it, the working V3 /3ds-redirect format used by web checkout
    // (verified live 2026-07-26).


    final http.Response response;
    try {
      response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'kashier-hash': session.hash,
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.networkError,
        details: e,
      );
    }

    final responseBody = _decodeResponse(response);

    if (response.statusCode != 200) {
      throw KashierPaymentError.fromApiResponse(
        responseBody,
        statusCode: response.statusCode,
      );
    }

    final result = CardPaymentResponse.fromApiResponse(responseBody);
    return result;
  }

  /// Pays with a saved card token.
  ///
  /// POST {fepBaseUrl}/v3/orders with PAY + CARD token.
  /// Returns a [CardPaymentResponse] — the handler interprets the status.
  Future<CardPaymentResponse> payWithSavedCard({
    required KashierSession session,
    required String cardToken,
    required String cvv,
  }) async {
    await _ensureOnline();
    final url = Uri.parse('${_mode.fepBaseUrl}/v3/orders');

    final body = _buildOrderBody(
      session: session,
      apiOperation: 'PAY',
      paymentMethod: {
        'type': 'CARD',
        'card': {
          'cardToken': cardToken,
          'securityCode': cvv,
          'enable3DS': session.enable3DS ?? true,
        },
      },
    );

    body['reconciliation'] = _buildPayReconciliation(session);
    // newPaymentUI is deliberately KEPT for PAY: without it the live backend
    // returns the legacy /3dsRedirect URL (methodUrl=undefined) whose page is
    // dead; with it, the working V3 /3ds-redirect format used by web checkout
    // (verified live 2026-07-26).


    final http.Response response;
    try {
      response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'kashier-hash': session.hash,
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      throw KashierPaymentError.fromCode(
        KashierErrorCode.networkError,
        details: e,
      );
    }

    final responseBody = _decodeResponse(response);

    if (response.statusCode != 200) {
      throw KashierPaymentError.fromApiResponse(
        responseBody,
        statusCode: response.statusCode,
      );
    }

    final result = CardPaymentResponse.fromApiResponse(responseBody);
    return result;
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      final contentType = response.headers['content-type'] ?? 'unknown';
      final summary = 'HTTP ${response.statusCode}, content-type: $contentType';
      throw KashierPaymentError.fromCode(
        KashierErrorCode.unknownError,
        message: 'Invalid response from server.',
        details: summary,
      );
    }
  }

  /// Disposes the HTTP client.
  void dispose() {
    _client.close();
  }
}
