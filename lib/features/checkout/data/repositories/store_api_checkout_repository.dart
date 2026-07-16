import 'dart:async';

import 'package:kidia_store_app/features/cart/data/models/cart_error_model.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_json.dart';
import 'package:kidia_store_app/features/cart/data/models/cart_model.dart';
import 'package:kidia_store_app/features/cart/data/network/cart_token_store.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:kidia_store_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:kidia_store_app/features/checkout/data/models/checkout_country_data.dart';
import 'package:kidia_store_app/features/checkout/data/network/checkout_api_transport.dart';
import 'package:kidia_store_app/features/checkout/data/models/checkout_field_definition_model.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_address.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_field_definition.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_submission.dart';
import 'package:kidia_store_app/features/checkout/domain/repositories/checkout_repository.dart';

class StoreApiCheckoutRepository implements CheckoutRepository {
  StoreApiCheckoutRepository({
    required this.cartRepository,
    required this.transport,
    required this.cartTokenStore,
  });

  final CartRepository cartRepository;
  final CheckoutApiTransport transport;

  /// Must be the same token store used by the cart data source.
  final CartTokenStore cartTokenStore;

  Future<void> _submissionTail = Future<void>.value();
  String? _lastSuccessfulKey;
  CheckoutOrderResult? _lastSuccessfulResult;

  @override
  Future<CheckoutState> loadCheckout() async {
    try {
      final Cart cart = await cartRepository.getCart();
      final List<CheckoutFieldDefinition> definitions =
          await _loadFieldDefinitions();
      return CheckoutState(cart: cart, fieldDefinitions: definitions);
    } on CartRepositoryException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutRepositoryException(
          kind: _cartFailureKind(error.kind),
          message: error.message,
          statusCode: error.statusCode,
          apiError: error.apiError,
          authoritativeCart: error.serverCart,
          cause: error,
        ),
        stackTrace,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutRepositoryException(
          kind: CheckoutFailureKind.unknown,
          message: 'Unable to load checkout.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  Future<List<CheckoutFieldDefinition>> _loadFieldDefinitions() async {
    try {
      final CheckoutApiResponse response = await transport.loadConfiguration();
      final Map<String, dynamic>? json = _objectOrNull(response.data);
      final dynamic rawFields = json?['fields'];
      if (rawFields is! List) {
        return const <CheckoutFieldDefinition>[];
      }
      final List<CheckoutFieldDefinition> fields = <CheckoutFieldDefinition>[];
      for (final dynamic rawField in rawFields) {
        final CheckoutFieldDefinition? field =
            CheckoutFieldDefinitionModel.tryParse(rawField);
        if (field != null) {
          fields.add(field);
        }
      }
      return _normalizeFieldDefinitions(fields, json!);
    } catch (_) {
      // Older plugin versions keep the safe built-in checkout fields. The
      // shopping flow must not fail merely because dynamic styling metadata
      // is not yet installed.
      return const <CheckoutFieldDefinition>[];
    }
  }

  List<CheckoutFieldDefinition> _normalizeFieldDefinitions(
    List<CheckoutFieldDefinition> fields,
    Map<String, dynamic> configuration,
  ) {
    final Map<String, dynamic>? defaults = _objectOrNull(
      configuration['defaults'],
    );
    String country =
        defaults?['country']?.toString().trim().toUpperCase() ?? '';
    if (country.isEmpty) {
      for (final CheckoutFieldDefinition field in fields) {
        if ((field.key == 'billing_country' ||
                field.key == 'shipping_country') &&
            field.defaultValue.trim().isNotEmpty) {
          country = field.defaultValue.trim().toUpperCase();
          break;
        }
      }
    }
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
      country = 'EG';
    }

    Map<String, String> states = _stringMap(defaults?['states']);
    if (states.isEmpty) {
      states = CheckoutCountryData.statesFor(country);
    }

    final List<CheckoutFieldDefinition> normalized =
        <CheckoutFieldDefinition>[];
    final Set<String> seenKeys = <String>{};
    for (final CheckoutFieldDefinition field in fields) {
      if (field.key == 'billing_email' || field.key == 'shipping_email') {
        continue;
      }
      if (!seenKeys.add(field.key)) {
        continue;
      }
      if (_isPostcodeField(field.key)) {
        // The live store requires a shipping postcode at API level even
        // though checkout does not use it to collect the customer's address.
        // Keep the schema entry for payload compatibility, but never ask the
        // customer to enter a value.
        normalized.add(
          field.copyWith(
            type: CheckoutFieldType.hidden,
            required: false,
            options: const <String, String>{},
            defaultValue: '',
          ),
        );
        continue;
      }
      if (_isCountryField(field.key)) {
        normalized.add(
          field.copyWith(
            type: CheckoutFieldType.hidden,
            required: false,
            options: const <String, String>{},
            defaultValue: country,
          ),
        );
        continue;
      }
      if (_isStateField(field.key)) {
        final Map<String, String> availableStates = field.options.isNotEmpty
            ? field.options
            : states;
        normalized.add(
          field.copyWith(
            type: availableStates.isEmpty
                ? CheckoutFieldType.text
                : CheckoutFieldType.select,
            required: availableStates.isNotEmpty ? true : field.required,
            options: availableStates,
          ),
        );
        continue;
      }
      normalized.add(field);
    }

    // A legacy checkout configuration can expose a required shipping field
    // without its billing counterpart. When the customer uses one address,
    // the app sends billing values as the shipping address, so that missing
    // counterpart would otherwise be impossible to enter. Mirror every
    // required standard shipping field into billing while keeping custom
    // plugin fields in their original group.
    final List<CheckoutFieldDefinition> shippingFields =
        List<CheckoutFieldDefinition>.of(normalized);
    for (final CheckoutFieldDefinition field in shippingFields) {
      final String? billingKey = _billingCounterpartFor(field);
      if (billingKey == null || !seenKeys.add(billingKey)) {
        continue;
      }
      normalized.add(
        CheckoutFieldDefinition(
          key: billingKey,
          group: CheckoutFieldGroup.billing,
          type: field.type,
          label: field.label,
          placeholder: field.placeholder,
          required: true,
          priority: field.priority,
          options: field.options,
          defaultValue: field.defaultValue,
          autocomplete: field.autocomplete
              .replaceAll('section-shipping', 'section-billing')
              .replaceAll('shipping ', 'billing '),
        ),
      );
    }
    normalized.sort(
      (CheckoutFieldDefinition first, CheckoutFieldDefinition second) =>
          first.priority.compareTo(second.priority),
    );

    return List<CheckoutFieldDefinition>.unmodifiable(normalized);
  }

  String? _billingCounterpartFor(CheckoutFieldDefinition field) {
    if (field.group != CheckoutFieldGroup.shipping ||
        !field.required ||
        !field.isVisible ||
        !field.key.startsWith('shipping_')) {
      return null;
    }
    final String suffix = field.key.substring('shipping_'.length);
    if (!<String>{
      'first_name',
      'last_name',
      'company',
      'address_1',
      'address_2',
      'city',
      'state',
      'postcode',
      'country',
      'phone',
    }.contains(suffix)) {
      return null;
    }
    return 'billing_$suffix';
  }

  Map<String, String> _stringMap(dynamic raw) {
    if (raw is! Map) {
      return const <String, String>{};
    }
    final Map<String, String> values = <String, String>{};
    for (final MapEntry<dynamic, dynamic> entry in raw.entries) {
      final String key = entry.key?.toString().trim() ?? '';
      final String value = entry.value?.toString().trim() ?? '';
      if (key.isNotEmpty && value.isNotEmpty) {
        values[key] = value;
      }
    }
    return Map<String, String>.unmodifiable(values);
  }

  bool _isCountryField(String key) =>
      key == 'billing_country' || key == 'shipping_country';

  bool _isStateField(String key) =>
      key == 'billing_state' || key == 'shipping_state';

  bool _isPostcodeField(String key) =>
      key == 'billing_postcode' || key == 'shipping_postcode';

  @override
  Future<Cart> updateCustomer({
    required CheckoutAddress billingAddress,
    required CheckoutAddress shippingAddress,
  }) async {
    try {
      String token = cartTokenStore.read()?.trim() ?? '';
      if (token.isEmpty) {
        await cartRepository.getCart();
        token = cartTokenStore.read()?.trim() ?? '';
      }
      if (token.isEmpty) {
        throw const CheckoutRepositoryException(
          kind: CheckoutFailureKind.configuration,
          message: 'The store did not issue a Cart-Token for checkout.',
        );
      }

      final CheckoutApiResponse response = await transport.updateCustomer(
        cartToken: token,
        body: <String, dynamic>{
          'billing_address': _billingAddressJson(billingAddress),
          'shipping_address': _shippingAddressJson(
            shippingAddress,
            billingAddress: billingAddress,
          ),
        },
      );
      return CartModel.fromJson(
        CartJson.object(response.data, 'updated_cart'),
      ).toEntity();
    } on CheckoutRepositoryException {
      rethrow;
    } on CheckoutApiTransportException catch (error, stackTrace) {
      Error.throwWithStackTrace(_transportFailure(error), stackTrace);
    } on CartRepositoryException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutRepositoryException(
          kind: _cartFailureKind(error.kind),
          message: error.message,
          statusCode: error.statusCode,
          apiError: error.apiError,
          authoritativeCart: error.serverCart,
          cause: error,
        ),
        stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutRepositoryException(
          kind: CheckoutFailureKind.invalidResponse,
          message:
              'The store returned invalid cart data after the address update.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<CheckoutOrderResult> placeOrder(CheckoutSubmission submission) {
    final Completer<CheckoutOrderResult> completer =
        Completer<CheckoutOrderResult>();
    _submissionTail = _submissionTail.then<void>((_) async {
      try {
        final String key = submission.idempotencyKey.trim();
        if (!RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(key)) {
          throw const CheckoutRepositoryException(
            kind: CheckoutFailureKind.invalidInput,
            message: 'A safe checkout idempotency key is required.',
          );
        }
        _validateSubmission(submission);
        if (_lastSuccessfulKey == key && _lastSuccessfulResult != null) {
          completer.complete(_lastSuccessfulResult);
          return;
        }

        String token = cartTokenStore.read()?.trim() ?? '';
        if (token.isEmpty) {
          await cartRepository.getCart();
          token = cartTokenStore.read()?.trim() ?? '';
        }
        if (token.isEmpty) {
          throw const CheckoutRepositoryException(
            kind: CheckoutFailureKind.configuration,
            message: 'The store did not issue a Cart-Token for checkout.',
          );
        }

        final CheckoutApiResponse response = await transport.placeOrder(
          cartToken: token,
          idempotencyKey: key,
          body: _submissionJson(submission),
        );
        final CheckoutOrderResult result = _parseOrderResult(response.data);
        _lastSuccessfulKey = key;
        _lastSuccessfulResult = result;
        completer.complete(result);
      } on CheckoutRepositoryException catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } on CheckoutApiTransportException catch (error, stackTrace) {
        completer.completeError(_transportFailure(error), stackTrace);
      } on CartRepositoryException catch (error, stackTrace) {
        completer.completeError(
          CheckoutRepositoryException(
            kind: _cartFailureKind(error.kind),
            message: error.message,
            statusCode: error.statusCode,
            apiError: error.apiError,
            authoritativeCart: error.serverCart,
            cause: error,
          ),
          stackTrace,
        );
      } on FormatException catch (error, stackTrace) {
        completer.completeError(
          CheckoutRepositoryException(
            kind: CheckoutFailureKind.invalidResponse,
            message: 'The store returned invalid checkout data.',
            cause: error,
          ),
          stackTrace,
        );
      } catch (error, stackTrace) {
        completer.completeError(
          CheckoutRepositoryException(
            kind: CheckoutFailureKind.unknown,
            message: 'Checkout failed unexpectedly.',
            cause: error,
          ),
          stackTrace,
        );
      }
    });
    return completer.future;
  }

  Map<String, dynamic> _submissionJson(CheckoutSubmission submission) {
    final String paymentMethod = submission.paymentMethodId.trim();
    return <String, dynamic>{
      'billing_address': _billingAddressJson(submission.billingAddress),
      'shipping_address': _shippingAddressJson(
        submission.shippingAddress,
        billingAddress: submission.billingAddress,
      ),
      'customer_note': submission.customerNote.trim(),
      // The app uses WooCommerce guest checkout. Stores that require an
      // account will return their authoritative registration error instead
      // of being misclassified as an invalid address by the client.
      'create_account': false,
      if (paymentMethod.isNotEmpty) 'payment_method': paymentMethod,

      // Gateway-specific fields (card data, tokens, nonces) are deliberately
      // outside this generic checkout. A dedicated gateway adapter can provide
      // them later without ever persisting secrets in this repository.
      'payment_data': const <Map<String, String>>[],
      if (submission.customFields.isNotEmpty) ...<String, dynamic>{
        // Classic checkout plugins do not register their fields in the Store
        // API additional_fields schema. Sending those keys at the top level
        // makes WooCommerce reject an otherwise valid order. Our registered
        // extension validates and persists the filtered classic fields.
        'extensions': <String, dynamic>{
          'woo_mobile_cms': <String, dynamic>{
            'checkout_fields': submission.customFields,
          },
        },
      },
    };
  }

  void _validateSubmission(CheckoutSubmission submission) {
    final CheckoutAddress billing = submission.billingAddress.trimmed();
    final CheckoutAddress shipping = submission.shippingAddress
        .trimmed()
        .copyWith(
          phone: submission.shippingAddress.phone.trim().isEmpty
              ? billing.phone
              : submission.shippingAddress.phone.trim(),
        );
    if (!_isValidStandardAddress(billing, requiresPhone: true) ||
        !_isValidStandardAddress(shipping, requiresPhone: true) ||
        (billing.email.isNotEmpty &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(billing.email)) ||
        submission.customerNote.trim().length > 1000) {
      throw const CheckoutRepositoryException(
        kind: CheckoutFailureKind.invalidInput,
        message: 'Checkout contains invalid standard customer fields.',
      );
    }
  }

  bool _isValidStandardAddress(
    CheckoutAddress address, {
    required bool requiresPhone,
  }) {
    final Map<String, String> states = CheckoutCountryData.statesFor(
      address.country,
    );
    return address.firstName.isNotEmpty &&
        address.lastName.isNotEmpty &&
        address.address1.isNotEmpty &&
        address.city.isNotEmpty &&
        (!requiresPhone || address.phone.isNotEmpty) &&
        (states.isEmpty || states.containsKey(address.state)) &&
        RegExp(r'^[A-Z]{2}$').hasMatch(address.country);
  }

  Map<String, String> _addressJson(CheckoutAddress source) {
    final CheckoutAddress address = source.trimmed();
    return <String, String>{
      'first_name': address.firstName,
      'last_name': address.lastName,
      // Some WooCommerce versions incorrectly retain old Customizer flags
      // that make hidden company/address-line-2 fields required by Store API.
      // A valid text fallback satisfies that API-only contract without adding
      // customer-facing fields the merchant removed from classic checkout.
      'company': _hiddenTextAddressValue(address.company),
      'address_1': address.address1,
      'address_2': _hiddenTextAddressValue(address.address2),
      'city': address.city,
      'state': address.state,
      // WooCommerce may retain postcode as required in Store API even when
      // the merchant removes it from checkout. A valid numeric fallback keeps
      // order submission compatible without exposing a customer-facing field.
      'postcode': _hiddenPostcodeValue(address.postcode),
      'country': address.country,
      'phone': address.phone,
    };
  }

  Map<String, String> _billingAddressJson(CheckoutAddress source) {
    final CheckoutAddress address = source.trimmed();
    return <String, String>{
      ..._addressJson(address),
      // Woo's Store API requires a billing email even when the classic
      // checkout hides it. The reserved .invalid domain keeps guest orders
      // non-deliverable without asking the customer for an email address.
      'email': address.email.isEmpty
          ? _guestEmailForPhone(address.phone)
          : address.email,
    };
  }

  Map<String, String> _shippingAddressJson(
    CheckoutAddress source, {
    required CheckoutAddress billingAddress,
  }) {
    final CheckoutAddress address = source.trimmed();
    final String phone = address.phone.isEmpty
        ? billingAddress.phone.trim()
        : address.phone;
    return _addressJson(address.copyWith(phone: phone));
  }

  String _hiddenTextAddressValue(String value) =>
      value.trim().isEmpty ? 'N/A' : value.trim();

  String _hiddenPostcodeValue(String value) =>
      value.trim().isEmpty ? '00000' : value.trim();

  String _guestEmailForPhone(String phone) {
    final StringBuffer digits = StringBuffer();
    for (final int rune in phone.runes) {
      if (rune >= 0x30 && rune <= 0x39) {
        digits.writeCharCode(rune);
      } else if (rune >= 0x0660 && rune <= 0x0669) {
        digits.write(rune - 0x0660);
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        digits.write(rune - 0x06F0);
      }
    }
    final String suffix = digits.isEmpty ? 'customer' : digits.toString();
    return 'guest-$suffix@no-email.invalid';
  }

  CheckoutOrderResult _parseOrderResult(dynamic raw) {
    final Map<String, dynamic> json = CartJson.object(raw, 'checkout');
    final int orderId = CartJson.integer(json['order_id']);
    if (orderId <= 0) {
      throw const FormatException('Checkout must return a positive order id.');
    }
    final Map<String, dynamic> paymentResult = CartJson.optionalObject(
      json['payment_result'],
      'payment_result',
    );
    final Uri? redirectUri = _webUri(paymentResult['redirect_url']);
    return CheckoutOrderResult(
      orderId: orderId,
      status: CartJson.text(json['status'], fallback: 'pending').trim(),
      paymentStatus: CartJson.text(
        paymentResult['payment_status'],
        fallback: 'pending',
      ).trim(),
      redirectUri: redirectUri,
    );
  }

  CheckoutRepositoryException _transportFailure(
    CheckoutApiTransportException error,
  ) {
    final Map<String, dynamic>? json = _objectOrNull(error.data);
    CartErrorModel? apiError;
    if (json != null) {
      try {
        apiError = CartErrorModel.fromJson(json);
      } on FormatException {
        apiError = null;
      }
    }
    Cart? authoritativeCart;
    final Map<String, dynamic>? data = _objectOrNull(json?['data']);
    final Map<String, dynamic>? cart = _objectOrNull(data?['cart']);
    if (cart != null) {
      try {
        authoritativeCart = CartModel.fromJson(cart).toEntity();
      } on FormatException {
        authoritativeCart = null;
      }
    }
    final CheckoutFailureKind kind = error.statusCode == 409
        ? CheckoutFailureKind.conflict
        : _transportFailureKind(error.kind, error.statusCode);
    return CheckoutRepositoryException(
      kind: kind,
      message: apiError?.message.trim().isNotEmpty == true
          ? apiError!.message.trim()
          : error.message,
      statusCode: error.statusCode,
      apiError: apiError?.toEntity(),
      fieldErrors: _checkoutFieldErrors(json),
      authoritativeCart: authoritativeCart,
      cause: error,
    );
  }

  Map<String, String> _checkoutFieldErrors(Map<String, dynamic>? json) {
    final Map<String, dynamic>? data = _objectOrNull(json?['data']);
    final Map<String, dynamic>? details = _objectOrNull(data?['details']);
    if (details == null) {
      return const <String, String>{};
    }

    final Map<String, String> errors = <String, String>{};
    for (final MapEntry<String, dynamic> context in details.entries) {
      final String? prefix = switch (context.key) {
        'billing_address' => 'billing',
        'shipping_address' => 'shipping',
        _ => null,
      };
      _collectCheckoutFieldErrors(context.value, prefix: prefix, into: errors);
    }
    return Map<String, String>.unmodifiable(errors);
  }

  void _collectCheckoutFieldErrors(
    dynamic raw, {
    required String? prefix,
    required Map<String, String> into,
  }) {
    if (raw is List) {
      for (final dynamic item in raw) {
        _collectCheckoutFieldErrors(item, prefix: prefix, into: into);
      }
      return;
    }
    final Map<String, dynamic>? error = _objectOrNull(raw);
    if (error == null) {
      return;
    }
    final Map<String, dynamic>? errorData = _objectOrNull(error['data']);
    final String rawKey = errorData?['key']?.toString().trim() ?? '';
    if (rawKey.isNotEmpty) {
      final String fieldKey = _canonicalCheckoutFieldKey(rawKey, prefix);
      final String message = error['message']?.toString().trim() ?? '';
      into.putIfAbsent(
        fieldKey,
        () => message.isEmpty ? 'This field is required.' : message,
      );
    }
    _collectCheckoutFieldErrors(
      error['additional_errors'],
      prefix: prefix,
      into: into,
    );
    _collectCheckoutFieldErrors(
      errorData?['additional_errors'],
      prefix: prefix,
      into: into,
    );
  }

  String _canonicalCheckoutFieldKey(String key, String? prefix) {
    if (key.startsWith('billing_') || key.startsWith('shipping_')) {
      return key;
    }
    if (prefix != null && RegExp(r'^[a-z0-9_]+$').hasMatch(key)) {
      return '${prefix}_$key';
    }
    return key;
  }

  Map<String, dynamic>? _objectOrNull(dynamic value) {
    if (value == null) {
      return null;
    }
    try {
      return CartJson.object(value, 'checkout_error');
    } on FormatException {
      return null;
    }
  }

  Uri? _webUri(dynamic value) {
    final Uri? uri = Uri.tryParse(value?.toString().trim() ?? '');
    final bool isLocalHttp =
        uri?.scheme == 'http' &&
        (uri?.host == 'localhost' || uri?.host == '127.0.0.1');
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && !isLocalHttp)) {
      return null;
    }
    return uri;
  }

  CheckoutFailureKind _transportFailureKind(
    CheckoutTransportFailureKind kind,
    int? statusCode,
  ) {
    if (statusCode == 400 || statusCode == 422) {
      return CheckoutFailureKind.invalidInput;
    }
    if (statusCode == 401 || statusCode == 403) {
      return CheckoutFailureKind.unauthorized;
    }
    if (statusCode != null && statusCode >= 500) {
      return CheckoutFailureKind.server;
    }
    return switch (kind) {
      CheckoutTransportFailureKind.configuration =>
        CheckoutFailureKind.configuration,
      CheckoutTransportFailureKind.timeout => CheckoutFailureKind.timeout,
      CheckoutTransportFailureKind.connection => CheckoutFailureKind.connection,
      CheckoutTransportFailureKind.cancelled => CheckoutFailureKind.unknown,
      CheckoutTransportFailureKind.certificate =>
        CheckoutFailureKind.connection,
      CheckoutTransportFailureKind.rejected =>
        CheckoutFailureKind.invalidResponse,
      CheckoutTransportFailureKind.invalidResponse =>
        CheckoutFailureKind.invalidResponse,
      CheckoutTransportFailureKind.unknown => CheckoutFailureKind.unknown,
    };
  }

  CheckoutFailureKind _cartFailureKind(CartFailureKind kind) {
    return switch (kind) {
      CartFailureKind.invalidInput => CheckoutFailureKind.invalidInput,
      CartFailureKind.configuration => CheckoutFailureKind.configuration,
      CartFailureKind.timeout => CheckoutFailureKind.timeout,
      CartFailureKind.connection => CheckoutFailureKind.connection,
      CartFailureKind.cancelled => CheckoutFailureKind.unknown,
      CartFailureKind.certificate => CheckoutFailureKind.connection,
      CartFailureKind.unauthorized => CheckoutFailureKind.unauthorized,
      CartFailureKind.notFound => CheckoutFailureKind.invalidResponse,
      CartFailureKind.conflict => CheckoutFailureKind.conflict,
      CartFailureKind.server => CheckoutFailureKind.server,
      CartFailureKind.invalidResponse => CheckoutFailureKind.invalidResponse,
      CartFailureKind.unknown => CheckoutFailureKind.unknown,
    };
  }
}
