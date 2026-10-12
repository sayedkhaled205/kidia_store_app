import 'dart:async';

import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/cart/data/models/cart_error_model.dart';
import 'package:mobishop_store_app/features/cart/data/models/cart_json.dart';
import 'package:mobishop_store_app/features/cart/data/models/cart_model.dart';
import 'package:mobishop_store_app/features/cart/data/network/cart_token_store.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_error.dart';
import 'package:mobishop_store_app/features/cart/domain/repositories/cart_repository.dart';
import 'package:mobishop_store_app/features/checkout/data/models/checkout_country_data.dart';
import 'package:mobishop_store_app/features/checkout/data/network/checkout_api_transport.dart';
import 'package:mobishop_store_app/features/checkout/data/network/checkout_safety_transport.dart';
import 'package:mobishop_store_app/features/checkout/data/storage/checkout_pending_attempt_store.dart';
import 'package:mobishop_store_app/features/checkout/data/models/checkout_field_definition_model.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_address.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_field_definition.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_submission.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_safety.dart';
import 'package:mobishop_store_app/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:mobishop_store_app/features/checkout/domain/repositories/checkout_recovery_repository.dart';

class StoreApiCheckoutRepository
    implements CheckoutRepository, CheckoutRecoveryRepository {
  StoreApiCheckoutRepository({
    required this.cartRepository,
    required this.transport,
    required this.cartTokenStore,
    CheckoutPendingAttemptStore? pendingAttemptStore,
    bool Function()? currentSessionIsValid,
    this.safetyTransport,
    this.requireServerSafety = false,
    this.customerId,
  }) : pendingAttemptStore =
           pendingAttemptStore ?? MemoryCheckoutPendingAttemptStore(),
       _currentSessionIsValid = currentSessionIsValid ?? (() => true);

  final CartRepository cartRepository;
  final CheckoutApiTransport transport;

  /// Must be the same token store used by the cart data source.
  final CartTokenStore cartTokenStore;
  final CheckoutPendingAttemptStore pendingAttemptStore;
  final bool Function() _currentSessionIsValid;
  final CheckoutSafetyTransport? safetyTransport;

  /// Legacy transport-only fixtures opt out explicitly; configured Native
  /// customer checkout must inject safetyTransport and require this contract.
  final bool requireServerSafety;

  /// Independently captured authenticated buyer, not a cart/address/customer
  /// value echoed by an order. currentSessionIsValid must bind this identity.
  final int? customerId;

  String? _lastSuccessfulKey;
  CheckoutOrderResult? _lastSuccessfulResult;

  @override
  Future<CheckoutState> loadCheckout() =>
      pendingAttemptStore.exclusive(_loadCheckout);

  Future<CheckoutState> _loadCheckout() async {
    bool unresolved = false;
    try {
      _assertCurrentSession();
      unresolved = (await _readAttempt())?.isUnresolved ?? false;
      _assertCurrentSession();
      if (unresolved) {
        // A fresh/empty basket cannot resolve a previously dispatched order.
        // Show the recovery warning immediately, even offline, before any
        // basket/configuration read can create a guest basket or time out.
        throw _unresolvedAttempt();
      }
      final Cart cart = await cartRepository.getCart();
      final List<CheckoutFieldDefinition> definitions =
          await _loadFieldDefinitions();
      bool enforced = false;
      if (requireServerSafety || safetyTransport != null) {
        try {
          enforced = (await _loadSafetyCapability()).enforced;
        } on CheckoutRepositoryException {
          // Read-only checkout fields remain usable while activation/recovery
          // is unavailable. The UI and placeOrder both disable unsafe checkout.
        }
      }
      _assertCurrentSession();
      return CheckoutState(
        cart: cart,
        fieldDefinitions: definitions,
        hasUnresolvedSubmission: unresolved,
        serverSafetyRequired: requireServerSafety || safetyTransport != null,
        serverSafetyEnforced: enforced,
      );
    } on CheckoutRepositoryException {
      rethrow;
    } on CartRepositoryException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutRepositoryException(
          kind: _cartFailureKind(error.kind),
          message: error.message,
          statusCode: error.statusCode,
          apiError: error.apiError,
          authoritativeCart: error.serverCart,
          cause: error,
          requiresOutcomeRecovery: unresolved,
        ),
        stackTrace,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutRepositoryException(
          kind: CheckoutFailureKind.unknown,
          message: 'Unable to load checkout.',
          cause: error,
          requiresOutcomeRecovery: unresolved,
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
  }) => pendingAttemptStore.exclusive(
    () => _updateCustomer(
      billingAddress: billingAddress,
      shippingAddress: shippingAddress,
    ),
  );

  Future<Cart> _updateCustomer({
    required CheckoutAddress billingAddress,
    required CheckoutAddress shippingAddress,
  }) async {
    try {
      _assertCurrentSession();
      final CheckoutPendingAttempt? previous = await _readAttempt();
      _assertCurrentSession();
      if (previous?.isUnresolved == true) {
        throw _unresolvedAttempt();
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

      _assertCurrentSession();
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
      _assertCurrentSession();
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
  Future<CheckoutOrderResult> placeOrder(CheckoutSubmission submission) =>
      pendingAttemptStore.exclusive(() => _placeOrder(submission));

  Future<CheckoutOrderResult> _placeOrder(CheckoutSubmission submission) async {
    bool dispatched = false;
    bool markerWritten = false;
    final String key = submission.idempotencyKey.trim();
    final bool protected = requireServerSafety || safetyTransport != null;
    try {
      _assertCurrentSession();
      final CheckoutPendingAttempt? previous = await _readAttempt();
      // An awaited secure read can outlive logout or a customer switch. Do
      // not expose either a persisted receipt or an in-memory receipt then.
      _assertCurrentSession();
      if (_lastSuccessfulKey == key && _lastSuccessfulResult != null) {
        return _lastSuccessfulResult!;
      }
      if (previous?.confirmedResult != null &&
          previous?.idempotencyKey == key) {
        return previous!.confirmedResult!;
      }
      if (previous?.isUnresolved == true) throw _unresolvedAttempt();
      if (!RegExp(r'^[A-Za-z0-9._:-]{1,128}$').hasMatch(key)) {
        throw const CheckoutRepositoryException(
          kind: CheckoutFailureKind.invalidInput,
          message: 'A safe checkout idempotency key is required.',
        );
      }
      _validateSubmission(submission);
      if (protected) {
        if (submission.confirmedTotal == null) {
          throw const CheckoutRepositoryException(
            kind: CheckoutFailureKind.invalidInput,
            message:
                'An exact buyer-confirmed total is required before checkout.',
          );
        }
        // Fresh capability evidence before every order POST. A cached flag or
        // a version number cannot protect a server whose guard was disabled.
        await _loadSafetyCapability();
        _assertCurrentSession();
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

      _assertCurrentSession();
      final CheckoutPendingAttempt attempt = CheckoutPendingAttempt(
        idempotencyKey: key,
        createdAtMicros: DateTime.now().microsecondsSinceEpoch,
      );
      // Write and read back before the first order POST. A crashed process
      // or new cart cannot silently drop an uncertain dispatch afterward.
      await pendingAttemptStore.write(attempt);
      markerWritten = true;
      final CheckoutPendingAttempt? recorded = await _readAttempt();
      if (recorded?.idempotencyKey != key ||
          recorded?.createdAtMicros != attempt.createdAtMicros ||
          recorded?.isUnresolved != true) {
        throw const CheckoutRepositoryException(
          kind: CheckoutFailureKind.configuration,
          message: 'The checkout attempt could not be safely recorded.',
        );
      }
      // Secure persistence is asynchronous. Logout/customer changes during
      // that await must not dispatch the captured customer's old form.
      _assertCurrentSession();
      dispatched = true;
      final CheckoutApiResponse response = await transport.placeOrder(
        cartToken: token,
        idempotencyKey: key,
        body: _submissionJson(submission, protected: protected),
      );
      _assertCurrentSession();
      if (protected && response.statusCode == 409) {
        // Concrete HTTP transport normally throws for409. Preserve the same
        // strict guard for adapters returning a typed response instead.
        throw CheckoutApiTransportException(
          kind: CheckoutTransportFailureKind.rejected,
          statusCode: 409,
          message: 'The platform rejected this checkout attempt.',
          data: response.data,
        );
      }
      if (response.statusCode != null &&
          (response.statusCode! < 200 || response.statusCode! >= 300)) {
        throw const FormatException(
          'Checkout did not confirm a successful response.',
        );
      }
      final CheckoutOrderResult result = protected
          ? _parseProtectedOrderResult(
              response.data,
              isFreeOrder: submission.confirmedTotal?.totalPrice == '0',
            )
          : _parseOrderResult(response.data);
      _lastSuccessfulKey = key;
      _lastSuccessfulResult = result;
      try {
        await pendingAttemptStore.write(
          CheckoutPendingAttempt(
            idempotencyKey: key,
            createdAtMicros: attempt.createdAtMicros,
            confirmedResult: result,
          ),
        );
      } catch (_) {
        // We already have a real positive receipt. Never transform that
        // success into a retry invitation. An unchanged pending marker keeps
        // another repository/restarted process blocked until real recovery.
      }
      _assertCurrentSession();
      return result;
    } on CheckoutRepositoryException catch (error, stackTrace) {
      if (markerWritten && !dispatched) {
        await _releaseKnownRejection(key);
      }
      Error.throwWithStackTrace(
        dispatched ? _requiringRecovery(error) : error,
        stackTrace,
      );
    } on CheckoutApiTransportException catch (error, stackTrace) {
      _assertCurrentSession(requiresOutcomeRecovery: dispatched);
      final bool rejectedBeforeDispatch =
          protected &&
          dispatched &&
          CheckoutAttemptRecovery.isProvenPreDispatchRejection(
            error.data,
            error.statusCode,
            expectedAttemptKey: key,
            expectedCustomerId: customerId,
          );
      final bool guardedRejection =
          protected &&
          dispatched &&
          error.statusCode == 409 &&
          error.data is Map &&
          error.data['protocol'] == 50 &&
          error.data['protocol'] is int &&
          error.data['code'] ==
              'mobishop_native_checkout50_confirmed_total_mismatch' &&
          error.data['data'] is Map &&
          error.data['data']['automatic_replay'] == false;
      final CheckoutRepositoryException mapped =
          rejectedBeforeDispatch || guardedRejection
          ? CheckoutRepositoryException(
              kind: CheckoutFailureKind.conflict,
              statusCode: 409,
              message: rejectedBeforeDispatch
                  ? 'The store confirmed that this attempt was rejected before checkout. Review current details before confirming again.'
                  : 'The confirmed total changed. Review the current amount before confirming again.',
              confirmedPrePaymentRejection: true,
              cause: error,
            )
          : _transportFailure(error);
      // Protected late errors are never reinterpreted as ordinary legacy
      // validation failures after the server claimed this buyer/attempt.
      if (dispatched &&
          (rejectedBeforeDispatch ||
              guardedRejection ||
              (!protected && _isDefinitiveValidationRejection(mapped)))) {
        await _releaseKnownRejection(key);
        _assertCurrentSession();
        Error.throwWithStackTrace(mapped, stackTrace);
      }
      Error.throwWithStackTrace(
        dispatched ? _requiringRecovery(mapped) : mapped,
        stackTrace,
      );
    } on CartRepositoryException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutRepositoryException(
          kind: _cartFailureKind(error.kind),
          message: error.message,
          statusCode: error.statusCode,
          apiError: error.apiError,
          authoritativeCart: error.serverCart,
          cause: error,
          requiresOutcomeRecovery: dispatched,
        ),
        stackTrace,
      );
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutRepositoryException(
          kind: dispatched
              ? CheckoutFailureKind.invalidResponse
              : CheckoutFailureKind.configuration,
          message: dispatched
              ? 'The store returned invalid checkout data.'
              : 'The checkout attempt could not be safely recorded.',
          cause: error,
          requiresOutcomeRecovery: dispatched,
        ),
        stackTrace,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutRepositoryException(
          kind: dispatched
              ? CheckoutFailureKind.unknown
              : CheckoutFailureKind.configuration,
          message: dispatched
              ? 'Checkout failed unexpectedly.'
              : 'Unable to safely record checkout. No order was sent.',
          cause: error,
          requiresOutcomeRecovery: dispatched,
        ),
        stackTrace,
      );
    }
  }

  Future<CheckoutSafetyCapability> _loadSafetyCapability() async {
    _assertCurrentSession();
    if (customerId == null || customerId! <= 0) {
      throw const CheckoutRepositoryException(
        kind: CheckoutFailureKind.configuration,
        message:
            'Protected checkout requires its independently authenticated customer identity.',
      );
    }
    final CheckoutSafetyTransport? safety = safetyTransport;
    if (safety == null) {
      throw const CheckoutRepositoryException(
        kind: CheckoutFailureKind.configuration,
        message: 'The platform checkout safety connector is not configured.',
      );
    }
    try {
      final CheckoutApiResponse response = await safety.loadCapabilities();
      _assertCurrentSession();
      if (response.statusCode != 200) {
        throw const FormatException('Checkout capability was not confirmed.');
      }
      final CheckoutSafetyCapability capability =
          CheckoutSafetyCapability.fromJson(response.data);
      if (!capability.enforced) {
        throw const FormatException(
          'The platform checkout guard is unavailable.',
        );
      }
      return capability;
    } on CheckoutRepositoryException {
      rethrow;
    } catch (error, stackTrace) {
      // This GET has not dispatched an order; do not create a false unknown
      // attempt. A pre-existing pending marker is handled by recovery below.
      _assertCurrentSession();
      Error.throwWithStackTrace(
        CheckoutRepositoryException(
          kind: CheckoutFailureKind.configuration,
          message:
              'The platform has not confirmed protected checkout. No order was sent.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<CheckoutAttemptRecovery> recoverPendingOrder() =>
      pendingAttemptStore.exclusive(_recoverPendingOrder);

  Future<CheckoutAttemptRecovery> _recoverPendingOrder() async {
    try {
      _assertCurrentSession();
      final CheckoutPendingAttempt? pending = await _readAttempt();
      _assertCurrentSession();
      if (pending == null) throw _unresolvedAttempt();
      await _loadSafetyCapability();
      _assertCurrentSession();
      final CheckoutApiResponse response = await safetyTransport!
          .recoverAttempt(
            idempotencyKey: pending.idempotencyKey,
            cartToken: cartTokenStore.read(),
          );
      _assertCurrentSession();
      final CheckoutAttemptRecovery recovery = CheckoutAttemptRecovery.parse(
        response.data,
        response.statusCode,
        expectedAttemptKey: pending.idempotencyKey,
        expectedCustomerId: customerId,
      );
      if (!recovery.isResolved) return recovery;
      if (recovery.state == CheckoutRecoveryState.rejectedBeforePayment ||
          recovery.state == CheckoutRecoveryState.rejectedBeforeDispatch) {
        await _releaseKnownRejection(pending.idempotencyKey);
        _assertCurrentSession();
        return recovery;
      }
      final CheckoutOrderResult receipt = recovery.orderResult!;
      await pendingAttemptStore.write(
        CheckoutPendingAttempt(
          idempotencyKey: pending.idempotencyKey,
          createdAtMicros: pending.createdAtMicros,
          confirmedResult: receipt,
        ),
      );
      _assertCurrentSession();
      final CheckoutPendingAttempt? recorded = await _readAttempt();
      _assertCurrentSession();
      if (recorded?.idempotencyKey != pending.idempotencyKey ||
          recorded?.confirmedResult?.orderId != receipt.orderId ||
          recorded?.confirmedResult?.status != receipt.status ||
          recorded?.confirmedResult?.paymentStatus != receipt.paymentStatus) {
        throw _unresolvedAttempt();
      }
      _lastSuccessfulKey = pending.idempotencyKey;
      _lastSuccessfulResult = receipt;
      return recovery;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        error is CheckoutRepositoryException
            ? _requiringRecovery(error)
            : _unresolvedAttempt(cause: error),
        stackTrace,
      );
    }
  }

  CheckoutOrderResult _parseProtectedOrderResult(
    dynamic raw, {
    required bool isFreeOrder,
  }) {
    final Map<String, dynamic> json = CartJson.object(raw, 'checkout');
    // Replayed server claims return the read-only recovery shape, not another
    // order dispatch. A locked positive receipt still does not unlock checkout.
    if (json['state'] != null) {
      final CheckoutAttemptRecovery recovery = CheckoutAttemptRecovery.parse(
        json,
        200,
      );
      if (recovery.state != CheckoutRecoveryState.orderCreated) {
        throw const FormatException(
          'The previous checkout remains unresolved.',
        );
      }
      return recovery.orderResult!;
    }
    final dynamic extensions = json['extensions'];
    final dynamic contract = extensions is Map
        ? extensions[CheckoutSafetyCapability.namespace]
        : null;
    final dynamic payment = json['payment_result'];
    if (contract is! Map ||
        contract['protocol'] != 50 ||
        contract['protocol'] is! int ||
        contract['enforced'] != true ||
        payment is! Map ||
        payment['payment_status'] != 'success' ||
        json['order_id'] is! int ||
        (json['order_id'] as int) <= 0 ||
        json['status'] is! String ||
        !RegExp(r'^[a-z0-9-]{1,64}$').hasMatch(json['status'] as String)) {
      throw const FormatException(
        'The store did not confirm protected checkout.',
      );
    }
    final CheckoutOrderResult result = _parseOrderResult(raw);
    // WooCommerce's process_without_payment returns the already-completed
    // order-received page as redirect_url. It is not a payment continuation.
    // Keep every gateway/pending/foreign redirect unless this exact guarded,
    // buyer-confirmed zero-value receipt is proved. Never navigate this URL.
    if (!isFreeOrder ||
        (result.status != 'processing' && result.status != 'completed') ||
        !_isOrderReceivedReceipt(result.redirectUri, result.orderId)) {
      return result;
    }
    return CheckoutOrderResult(
      orderId: result.orderId,
      status: result.status,
      paymentStatus: result.paymentStatus,
    );
  }

  bool _isOrderReceivedReceipt(Uri? uri, int orderId) {
    final Uri? storeUri = _webUri(AppConfig.apiBaseUrl);
    final String storePath =
        storeUri?.path.replaceFirst(RegExp(r'/+$'), '') ?? '';
    return uri != null &&
        storeUri != null &&
        uri.scheme == 'https' &&
        uri.scheme == storeUri.scheme &&
        uri.host == storeUri.host &&
        uri.port == storeUri.port &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment &&
        uri.path.startsWith('$storePath/') &&
        !uri.pathSegments.any((part) => part == '.' || part == '..') &&
        RegExp('/order-received/$orderId/?\$').hasMatch(uri.path) &&
        RegExp(r'^key=wc_order_[A-Za-z0-9]+$').hasMatch(uri.query);
  }

  Future<CheckoutPendingAttempt?> _readAttempt() async {
    try {
      return await pendingAttemptStore.read();
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CheckoutRepositoryException(
          kind: CheckoutFailureKind.configuration,
          message:
              'Unable to verify the previous checkout attempt. No new order was sent.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  Future<void> _releaseKnownRejection(String key) async {
    try {
      await pendingAttemptStore.clearKnownRejection(key);
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(_unresolvedAttempt(cause: error), stackTrace);
    }
  }

  bool _isDefinitiveValidationRejection(CheckoutRepositoryException error) =>
      (error.kind == CheckoutFailureKind.invalidInput &&
          (error.statusCode == 400 || error.statusCode == 422) &&
          error.apiError?.code == 'rest_invalid_param' &&
          error.fieldErrors.isNotEmpty) ||
      (error.kind == CheckoutFailureKind.conflict &&
          error.statusCode == 409 &&
          error.apiError?.code == 'woocommerce_rest_cart_changed' &&
          error.authoritativeCart != null);

  CheckoutRepositoryException _unresolvedAttempt({
    Object? cause,
  }) => CheckoutRepositoryException(
    kind: CheckoutFailureKind.unknown,
    message:
        'The previous order outcome is unconfirmed. Check your order history or contact the store before placing another order.',
    requiresOutcomeRecovery: true,
    cause: cause,
  );

  CheckoutRepositoryException _requiringRecovery(
    CheckoutRepositoryException error,
  ) => CheckoutRepositoryException(
    kind: error.kind,
    message: error.message,
    statusCode: error.statusCode,
    apiError: error.apiError,
    fieldErrors: error.fieldErrors,
    authoritativeCart: error.authoritativeCart,
    cause: error.cause,
    requiresOutcomeRecovery: true,
  );

  void _assertCurrentSession({bool requiresOutcomeRecovery = false}) {
    if (!_currentSessionIsValid()) {
      throw CheckoutRepositoryException(
        kind: CheckoutFailureKind.unauthorized,
        statusCode: 401,
        message: 'Checkout requires its current signed-in customer.',
        requiresOutcomeRecovery: requiresOutcomeRecovery,
      );
    }
  }

  Map<String, dynamic> _submissionJson(
    CheckoutSubmission submission, {
    bool protected = false,
  }) {
    final String paymentMethod = submission.paymentMethodId.trim();
    return <String, dynamic>{
      'billing_address': _billingAddressJson(submission.billingAddress),
      'shipping_address': _shippingAddressJson(
        submission.shippingAddress,
        billingAddress: submission.billingAddress,
      ),
      'customer_note': submission.customerNote.trim(),
      // Registration is completed before this route. The companion plugin
      // authenticates the Store API request with the app session, so Woo can
      // attach the order to the existing customer without creating a second
      // account during checkout.
      'create_account': false,
      if (paymentMethod.isNotEmpty) 'payment_method': paymentMethod,

      // Gateway-specific fields (card data, tokens, nonces) are deliberately
      // outside this generic checkout. A dedicated gateway adapter can provide
      // them later without ever persisting secrets in this repository.
      'payment_data': const <Map<String, String>>[],
      // The extension namespace also marks this order as originating from the
      // mobile app, even when this store has no custom checkout fields.
      'extensions': <String, dynamic>{
        if (protected)
          CheckoutSafetyCapability.namespace: <String, dynamic>{
            'protocol': CheckoutSafetyCapability.protocol,
            'confirmed': submission.confirmedTotal!.toJson(),
          },
        'mobishop_cms': <String, dynamic>{
          'checkout_fields': submission.customFields,
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
