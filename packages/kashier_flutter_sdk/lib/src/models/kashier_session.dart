/// Internal representation of a Kashier payment session.
///
/// This class is not exported to merchants. It holds session details
/// fetched from the Kashier API.
class KashierSession {
  final String sessionId;
  final double amount;

  /// The raw amount value as returned by the backend (preserves int/double type).
  final num rawAmount;
  final double? originalAmount;
  final num? rawOriginalAmount;
  final String currency;
  final String status;
  final String merchantId;
  final String orderReference;
  final String storeName;
  final String hash;
  final List<String> allowedMethods;
  final List<String> supportedNetworks;

  /// The interaction source for payment requests (e.g., "ECOMMERCE").
  final String interactionSource;

  /// Optional customer details from session.
  final KashierCustomer? customer;

  /// Optional order description.
  final String? description;

  /// Whether 3DS authentication is enabled for card payments.
  final bool? enable3DS;

  /// Card save behavior: "optional", "forced", or null (hidden).
  final String? saveCard;

  /// Whether to retrieve saved cards for the customer.
  final bool? retrieveSavedCard;

  /// Merchant brand color hex string (e.g., "#FF5733").
  final String? brandColor;

  /// Optional reconciliation URLs.
  final String? serverWebhook;
  final String? merchantRedirect;

  const KashierSession({
    required this.sessionId,
    required this.amount,
    required this.rawAmount,
    this.originalAmount,
    this.rawOriginalAmount,
    required this.currency,
    required this.status,
    required this.merchantId,
    required this.orderReference,
    required this.storeName,
    required this.hash,
    required this.allowedMethods,
    required this.supportedNetworks,
    this.interactionSource = 'ECOMMERCE',
    this.customer,
    this.description,
    this.enable3DS,
    this.saveCard,
    this.retrieveSavedCard,
    this.brandColor,
    this.serverWebhook,
    this.merchantRedirect,
  });

  /// Creates a [KashierSession] from a JSON map returned by the Kashier API.
  ///
  /// Expected shape: `{ "message": "success", "data": { ... } }`
  factory KashierSession.fromJson(Map<String, dynamic> json, String sessionId) {
    final data = json['data'] as Map<String, dynamic>? ?? json;
    final params = data['paymentParams'] as Map<String, dynamic>? ?? {};

    // storeName: prefer paymentParams.storeName, fallback to paymentParams.store
    final storeName = params['storeName'] as String? ??
        params['store'] as String? ??
        'Kashier';

    // Parse customer if present
    KashierCustomer? customer;
    final customerData = params['customer'] as Map<String, dynamic>?;
    if (customerData != null) {
      customer = KashierCustomer.fromJson(customerData);
    }

    // Parse allowedMethods: comma-separated string from paymentParams.
    // Not present or empty string → empty list (all methods allowed).
    // Non-empty string → split by comma into explicit method list.
    final rawAllowedMethods = params['allowedMethods'];
    List<String> allowedMethods;
    if (rawAllowedMethods is String && rawAllowedMethods.isNotEmpty) {
      allowedMethods = rawAllowedMethods
          .split(',')
          .map((m) => m.trim())
          .where((m) => m.isNotEmpty)
          .toList();
    } else if (rawAllowedMethods is List && rawAllowedMethods.isNotEmpty) {
      allowedMethods = List<String>.from(rawAllowedMethods);
    } else {
      // Not present, empty string, or empty list → all methods allowed.
      allowedMethods = <String>[];
    }

    return KashierSession(
      sessionId: data['_id'] as String? ?? sessionId,
      amount:
          (params['amount'] as num? ?? data['amount'] as num? ?? 0).toDouble(),
      rawAmount: (params['amount'] ?? data['amount'] ?? 0) as num,
      originalAmount: (params['originalAmount'] as num?)?.toDouble(),
      rawOriginalAmount: params['originalAmount'] as num?,
      currency: params['currency'] as String? ?? 'EGP',
      status: data['status'] as String? ?? 'UNKNOWN',
      merchantId: data['merchantId'] as String? ?? '',
      orderReference: params['order'] as String? ?? '',
      storeName: storeName,
      hash: params['hash'] as String? ?? '',
      description: params['description'] as String?,
      enable3DS: params['enable3DS'] as bool?,
      saveCard: params['saveCard'] as String?,
      retrieveSavedCard: params['retrieveSavedCard'] as bool?,
      brandColor: data['brandColor'] as String?,
      serverWebhook:
          params['serverWebhook'] as String? ?? params['webhookUrl'] as String?,
      merchantRedirect: params['merchantRedirect'] as String?,
      customer: customer,
      interactionSource: params['interactionSource'] as String? ?? 'ECOMMERCE',
      allowedMethods: allowedMethods,
      supportedNetworks: List<String>.from(
        data['supportedNetworks'] as List? ??
            <String>['visa', 'mastercard', 'meeza'],
      ),
    );
  }
}

/// Internal representation of customer details from a Kashier session.
class KashierCustomer {
  final String? id;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? reference;

  const KashierCustomer({
    this.id,
    this.name,
    this.firstName,
    this.lastName,
    this.email,
    this.reference,
  });

  factory KashierCustomer.fromJson(Map<String, dynamic> json) {
    return KashierCustomer(
      id: json['id'] as String?,
      name: json['name'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      email: json['Customer Email'] as String? ?? json['email'] as String?,
      reference: json['reference'] as String?,
    );
  }

  /// Returns true if any customer field has a non-empty value.
  bool get hasData =>
      _isNotEmpty(id) ||
      _isNotEmpty(name) ||
      _isNotEmpty(firstName) ||
      _isNotEmpty(lastName) ||
      _isNotEmpty(email) ||
      _isNotEmpty(reference);

  /// Converts to the JSON shape expected by the /v3/orders API.
  Map<String, dynamic> toOrderJson() {
    final map = <String, dynamic>{};
    if (_isNotEmpty(id)) map['id'] = id;
    if (_isNotEmpty(name)) map['name'] = name;
    if (_isNotEmpty(reference)) map['reference'] = reference;
    if (_isNotEmpty(firstName)) map['firstName'] = firstName;
    if (_isNotEmpty(lastName)) map['lastName'] = lastName;
    if (_isNotEmpty(email)) map['email'] = email;
    return map;
  }

  static bool _isNotEmpty(String? value) => value != null && value.isNotEmpty;
}
