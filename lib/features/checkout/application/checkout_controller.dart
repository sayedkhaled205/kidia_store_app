import 'dart:async';
import 'dart:collection';
import 'dart:math';
import '../domain/entities/saved_checkout_address92.dart';

import 'package:flutter/foundation.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart_totals.dart';
import 'package:mobishop_store_app/features/checkout/data/models/checkout_country_data.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_address.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_field_definition.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_submission.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_safety.dart';
import 'package:mobishop_store_app/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:mobishop_store_app/features/checkout/domain/repositories/checkout_recovery_repository.dart';

enum CheckoutStatus { initial, loading, ready, submitting, success, failure }

class CheckoutController extends ChangeNotifier {
  static const String _unresolvedOrderMessage =
      'The store may have received this order, but its result could not be confirmed. '
      'Check your order history or contact the store before placing another order. '
      'Retrying is disabled here to avoid a duplicate.';

  CheckoutController({
    required this.repository,
    this.initialEmail = '',
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final CheckoutRepository repository;
  final String initialEmail;
  final DateTime Function() _clock;

  CheckoutStatus _status = CheckoutStatus.initial;
  CheckoutState? _checkout;
  CheckoutAddress _billingAddress = const CheckoutAddress();
  CheckoutAddress _shippingAddress = const CheckoutAddress();
  bool _shipToDifferentAddress = false;
  String _customerNote = '';
  String _paymentMethodId = '';
  Map<String, String> _customFieldValues = const <String, String>{};
  Map<String, String> _fieldErrors = const <String, String>{};
  String? _loadError;
  String? _submitError;
  CheckoutOrderResult? _orderResult;
  Future<CheckoutOrderResult?>? _activeSubmission;
  Future<CheckoutOrderResult?>? _activeRecovery;
  Future<void>? _activeCustomerUpdate;
  Timer? _customerUpdateDebounce;
  String? _pendingIdempotencyKey;
  String? _addressUpdateError;
  int _submissionSequence = 0;
  int _requestSerial = 0;
  int _customerUpdateSerial = 0;
  int _addressRevision = 0;
  int _quotedRevision = 0;
  bool _isSelectingShipping = false;
  bool get supportsShippingQuotes => repository is CheckoutShippingRepository;
  bool get isUpdatingShipping =>
      _isUpdatingCustomer || _isSelectingShipping || _customerUpdateDirty;
  bool get shippingQuoteCurrent =>
      !isUpdatingShipping &&
      _quotedRevision == _addressRevision &&
      _addressUpdateError == null;
  bool get shippingReady =>
      !needsShipping ||
      (shippingQuoteCurrent &&
          cart?.hasCalculatedShipping == true &&
          cart!.shippingPackages.isNotEmpty &&
          cart!.shippingPackages.every((package) => package.hasSelection));

  bool _customerUpdateDirty = false;
  bool _isUpdatingCustomer = false;
  bool _isRecoveringOrder = false;
  bool _hasUnresolvedSubmission = false;
  bool _isDisposed = false;

  CheckoutStatus get status => _status;
  CheckoutState? get checkout => _checkout;
  Cart? get cart => _checkout?.cart;
  CheckoutAddress get billingAddress => _billingAddress;
  CheckoutAddress get shippingAddress => _shippingAddress;
  bool get shipToDifferentAddress => _shipToDifferentAddress;
  bool get allowDifferentShippingAddress =>
      needsShipping && (_checkout?.allowDifferentShippingAddress ?? false);
  String get customerNote => _customerNote;
  String get paymentMethodId => _paymentMethodId;
  List<String> get paymentMethodIds =>
      _checkout?.paymentMethodIds ?? const <String>[];
  String? paymentMethodLabel(String id) => _checkout?.paymentMethodLabel(id);
  bool paymentMethodSupported(String id) =>
      _checkout?.nativePaymentAdapters[id] != 'unavailable';
  int addressSelectionRevision = 0;
  String? _selectedSavedAddressId;
  Map<String, String> _savedAddressContactDefaults = const {};
  bool _editingSavedAddress = false;
  String? get selectedSavedAddressId => _selectedSavedAddressId;
  List<SavedCheckoutAddress92> get savedAddresses =>
      SavedCheckoutAddress92.distinct(_checkout?.savedAddresses ?? const [], defaults: _savedAddressContactDefaults);

  bool get showBillingEditor => _selectedSavedAddressId == null ||
      _editingSavedAddress || !_billingAddressComplete ||
      _fieldErrors.keys.any(_isBillingError);

  bool _isBillingError(String key) =>
      key.startsWith('billing_') || key.startsWith('billing.') ||
      (_checkout?.fieldDefinitions.any((field) => field.key == key &&
          field.group == CheckoutFieldGroup.billing) ?? false);

  bool get _billingAddressComplete {
    final errors = <String, String>{};
    if (hasDynamicFields) {
      _validateDynamicFields(errors);
    } else {
      _validateAddress(_billingAddress, prefix: 'billing',
          requiresEmail: false, requiresPhone: true, errors: errors);
    }
    return !errors.keys.any(_isBillingError);
  }

  void editSavedAddress() {
    if (!_canEditForm) return;
    _editingSavedAddress = true;
    _notify();
  }


  void selectSavedAddress(Map<String, String> values, {String? addressId}) {
    if (!_canEditForm) return;
    setShipToDifferentAddress(false);
    // Replace the address as a whole. Missing optional fields belong to the
    // selected address too; retaining them would mix two customers' locations.
    updateBillingAddress(CheckoutAddress(
      firstName: values['first_name'] ?? '',
      lastName: values['last_name'] ?? '',
      company: values['company'] ?? '',
      address1: values['address_1'] ?? '',
      address2: values['address_2'] ?? '',
      city: values['city'] ?? '',
      state: values['state'] ?? '',
      postcode: values['postcode'] ?? '',
      country: values['country'] ?? _billingAddress.country,
      email: values['email'] ?? _billingAddress.email,
      phone: values['phone'] ?? _billingAddress.phone,
    ));
    for (final field in _checkout?.fieldDefinitions ?? <CheckoutFieldDefinition>[]) {
      if (field.group == CheckoutFieldGroup.billing && !const {'billing_first_name', 'billing_last_name', 'billing_company', 'billing_address_1', 'billing_address_2', 'billing_city', 'billing_state', 'billing_postcode', 'billing_country', 'billing_email', 'billing_phone'}.contains(field.key)) {
        final key = field.key.replaceFirst(RegExp(r'^billing_'), '');
        setFieldValue(field.key, values[key] ?? field.defaultValue);
      }
    }
    _selectedSavedAddressId = addressId ?? savedAddresses
        .where((row) => matchesSavedAddress(row.values)).firstOrNull?.id;
    _editingSavedAddress = !_billingAddressComplete;
    // Old validation messages must not follow a different selected address.
    _fieldErrors = {for (final entry in _fieldErrors.entries)
      if (!_isBillingError(entry.key)) entry.key: entry.value};
    addressSelectionRevision++;
    _notify();
  }

  void enterNewAddress() {
    if (!_canEditForm) return;
    selectSavedAddress({
      'first_name': _billingAddress.firstName,
      'last_name': _billingAddress.lastName,
      'country': _billingAddress.country,
      'email': _billingAddress.email,
      'phone': _billingAddress.phone,
    });
  }

  bool matchesSavedAddress(Map<String, String> values) {
    if (_billingAddress.address1.isEmpty) return false;
    final coreKeys = {'first_name', 'last_name', 'company', 'address_1',
      'address_2', 'city', 'state', 'postcode', 'country'};
    for (final key in {...coreKeys, ...values.keys}) {
      // A missing contact uses the signed-in customer's existing contact.
      if ((key == 'email' || key == 'phone') && !values.containsKey(key)) continue;
      final fieldKey = (_checkout?.fieldDefinitions.any((field) => field.key == key &&
          field.group == CheckoutFieldGroup.billing) ?? false) ? key : 'billing_$key';
      if (_valueForKey(fieldKey).trim() != (values[key] ?? '').trim()) return false;
    }
    return true;
  }

  Map<String, String> get fieldErrors =>
      UnmodifiableMapView<String, String>(_fieldErrors);
  String? get loadError => _loadError;
  String? get submitError => _submitError;
  String? get addressUpdateError => _addressUpdateError;
  CheckoutOrderResult? get orderResult => _orderResult;
  bool get isSubmitting => _status == CheckoutStatus.submitting;
  bool get hasActiveSubmission => _activeSubmission != null;
  bool get isUpdatingCustomer => _isUpdatingCustomer;
  bool get isRecoveringOrder => _isRecoveringOrder;
  bool get canRecoverOrder =>
      !_isDisposed &&
      _hasUnresolvedSubmission &&
      !_isRecoveringOrder &&
      repository is CheckoutRecoveryRepository;

  /// A cart reload is not proof that an uncertain order was rejected.
  /// This controller cannot safely retry without a server recovery contract.
  bool get hasUnresolvedSubmission => _hasUnresolvedSubmission;
  bool get needsPayment => _checkout?.needsPayment ?? false;
  bool get needsShipping => _checkout?.needsShipping ?? false;
  bool get hasDynamicFields => _checkout?.hasDynamicFields ?? false;
  bool get canSubmit =>
      !_hasUnresolvedSubmission &&
      !_isRecoveringOrder &&
      (_checkout?.serverSafetyRequired != true ||
          _checkout?.serverSafetyEnforced == true) &&
      _status == CheckoutStatus.ready &&
      cart?.isEmpty == false &&
      !isUpdatingShipping &&
      (!supportsShippingQuotes || shippingReady);

  String? errorFor(String field) => _fieldErrors[field];

  List<CheckoutFieldDefinition> fieldsFor(CheckoutFieldGroup group) {
    return List<CheckoutFieldDefinition>.unmodifiable(
      (_checkout?.fieldDefinitions ?? const <CheckoutFieldDefinition>[])
          .where(
            (CheckoutFieldDefinition field) =>
                field.group == group && field.isVisible,
          )
          .map(_fieldForCurrentCountry),
    );
  }

  CheckoutFieldDefinition _fieldForCurrentCountry(
    CheckoutFieldDefinition field,
  ) {
    if (field.optionsByCountry.isEmpty) return field;
    final country = field.group == CheckoutFieldGroup.shipping
        ? _effectiveShippingAddress().country
        : _billingAddress.country;
    final options = field.optionsByCountry[country] ?? const <String, String>{};
    return field.copyWith(
      options: options,
      type: options.isEmpty ? CheckoutFieldType.text : CheckoutFieldType.select,
    );
  }

  String valueForField(CheckoutFieldDefinition field) {
    return _valueForKey(field.key, fallback: field.defaultValue);
  }

  Future<void> load() async {
    if (_isDisposed ||
        _activeSubmission != null ||
        _activeRecovery != null ||
        _status == CheckoutStatus.submitting ||
        _status == CheckoutStatus.success) {
      return;
    }
    if (_hasUnresolvedSubmission) {
      // Neither a refreshed nor an empty cart proves whether the dispatched
      // order was created. Keep the original attempt and visible warning.
      _submitError = _unresolvedOrderMessage;
      _notify();
      return;
    }
    final int serial = ++_requestSerial;
    _status = CheckoutStatus.loading;
    _loadError = null;
    _submitError = null;
    _fieldErrors = const <String, String>{};
    _notify();
    try {
      final CheckoutState loaded = await repository.loadCheckout();
      if (!_canCommit(serial)) {
        return;
      }
      _checkout = loaded;
      _billingAddress = CheckoutAddress.fromCartAddress(
        loaded.cart.billingAddress,
      );
      final String accountEmail = initialEmail.trim();
      if (_isValidEmail(accountEmail) &&
          (_billingAddress.email.trim().isEmpty ||
              _billingAddress.email.trim().endsWith('@no-email.invalid'))) {
        _billingAddress = _billingAddress.copyWith(email: accountEmail);
      }
      _shippingAddress = CheckoutAddress.fromCartAddress(
        loaded.cart.shippingAddress,
      );
      _applyDefaultAddresses(loaded.fieldDefinitions);
      _applyDefaultCountries(loaded.fieldDefinitions);
      _shipToDifferentAddress =
          loaded.needsShipping &&
          loaded.allowDifferentShippingAddress &&
          _hasAddress(_shippingAddress) &&
          !_sameAddress(_billingAddress, _shippingAddress);
      _paymentMethodId = loaded.paymentMethodIds.length == 1
          ? loaded.paymentMethodIds.single
          : '';
      _customerNote =
          loaded.fieldDefinitions
              .where((field) => field.key == 'order_comments')
              .map((field) => field.defaultValue)
              .firstOrNull ??
          '';
      _customFieldValues = <String, String>{
        for (final CheckoutFieldDefinition field in loaded.fieldDefinitions)
          if (!_isCoreCheckoutField(field.key) && field.defaultValue.isNotEmpty)
            field.key: field.defaultValue,
      };
      _savedAddressContactDefaults = {'email': _billingAddress.email, 'phone': _billingAddress.phone};
      _selectedSavedAddressId = savedAddresses
          .where((row) => matchesSavedAddress(row.values)).firstOrNull?.id;
      _editingSavedAddress = !_billingAddressComplete;
      _pendingIdempotencyKey = null;
      _addressUpdateError = null;
      _customerUpdateDirty = false;
      _addressRevision++;
      _quotedRevision = _addressRevision;
      _orderResult = null;
      _status = CheckoutStatus.ready;
      if (loaded.hasUnresolvedSubmission) {
        _retainUnresolvedSubmission();
        return;
      }
      if (supportsShippingQuotes &&
          _effectiveShippingAddress().country.isNotEmpty) {
        _scheduleCustomerUpdate();
      }
      _notify();
    } on CheckoutRepositoryException catch (error) {
      if (error.requiresOutcomeRecovery && _canCommit(serial)) {
        _retainUnresolvedSubmission();
        return;
      }
      _commitLoadFailure(serial, error.message);
    } catch (_) {
      _commitLoadFailure(serial, 'Unable to load checkout. Please try again.');
    }
  }

  void updateBillingAddress(CheckoutAddress address) {
    if (!_canEditForm) return;
    _selectedSavedAddressId = null;
    _billingAddress = address;
    _onFormChanged('billing.');
    _scheduleCustomerUpdate();
  }

  void updateShippingAddress(CheckoutAddress address) {
    if (!_canEditForm) return;
    _shippingAddress = address;
    _onFormChanged('shipping.');
    _scheduleCustomerUpdate();
  }

  void setShipToDifferentAddress(bool value) {
    if (!_canEditForm) return;
    if (value && !allowDifferentShippingAddress) return;
    if (_shipToDifferentAddress == value) {
      return;
    }
    _shipToDifferentAddress = value;
    _onFormChanged('shipping.');
    _scheduleCustomerUpdate();
  }

  void setCustomerNote(String value) {
    if (!_canEditForm) return;
    if (_customerNote == value) {
      return;
    }
    _customerNote = value;
    _onFormChanged('customerNote');
  }

  void setPaymentMethod(String value) {
    if (!_canEditForm) return;
    final String method = value.trim();
    if (_paymentMethodId == method) {
      return;
    }
    _paymentMethodId = method;
    _onFormChanged('paymentMethod');
  }

  void setFieldValue(String key, String value) {
    if (!_canEditForm) return;
    final String fieldKey = key.trim();
    if (fieldKey.isEmpty) {
      return;
    }
    switch (fieldKey) {
      case 'billing_first_name':
        _billingAddress = _billingAddress.copyWith(firstName: value);
      case 'billing_last_name':
        _billingAddress = _billingAddress.copyWith(lastName: value);
      case 'billing_company':
        _billingAddress = _billingAddress.copyWith(company: value);
      case 'billing_address_1':
        _billingAddress = _billingAddress.copyWith(address1: value);
      case 'billing_address_2':
        _billingAddress = _billingAddress.copyWith(address2: value);
      case 'billing_city':
        _billingAddress = _billingAddress.copyWith(city: value);
      case 'billing_state':
        _billingAddress = _billingAddress.copyWith(state: value);
      case 'billing_postcode':
        _billingAddress = _billingAddress.copyWith(postcode: value);
      case 'billing_country':
        _billingAddress = _billingAddress.copyWith(
          country: value,
          state: '',
          postcode: '',
        );
      case 'billing_email':
        _billingAddress = _billingAddress.copyWith(email: value);
      case 'billing_phone':
        _billingAddress = _billingAddress.copyWith(phone: value);
      case 'shipping_first_name':
        _shippingAddress = _shippingAddress.copyWith(firstName: value);
      case 'shipping_last_name':
        _shippingAddress = _shippingAddress.copyWith(lastName: value);
      case 'shipping_company':
        _shippingAddress = _shippingAddress.copyWith(company: value);
      case 'shipping_address_1':
        _shippingAddress = _shippingAddress.copyWith(address1: value);
      case 'shipping_address_2':
        _shippingAddress = _shippingAddress.copyWith(address2: value);
      case 'shipping_city':
        _shippingAddress = _shippingAddress.copyWith(city: value);
      case 'shipping_state':
        _shippingAddress = _shippingAddress.copyWith(state: value);
      case 'shipping_postcode':
        _shippingAddress = _shippingAddress.copyWith(postcode: value);
      case 'shipping_country':
        _shippingAddress = _shippingAddress.copyWith(
          country: value,
          state: '',
          postcode: '',
        );
      case 'shipping_email':
        _shippingAddress = _shippingAddress.copyWith(email: value);
      case 'shipping_phone':
        _shippingAddress = _shippingAddress.copyWith(phone: value);
      case 'order_comments':
        _customerNote = value;
      default:
        _customFieldValues = Map<String, String>.unmodifiable(<String, String>{
          ..._customFieldValues,
          fieldKey: value,
        });
    }
    if (_isBillingError(fieldKey)) _selectedSavedAddressId = null;
    _onFormChanged(fieldKey);
    if (fieldKey.startsWith('billing_') || fieldKey.startsWith('shipping_')) {
      _scheduleCustomerUpdate();
    }
  }

  bool validate() {
    if (_hasUnresolvedSubmission) {
      _submitError = _unresolvedOrderMessage;
      _notify();
      return false;
    }
    final Map<String, String> errors = <String, String>{};
    final Cart? currentCart = cart;
    if (currentCart == null || currentCart.isEmpty) {
      errors['cart'] = 'Your cart is empty.';
    }

    if (hasDynamicFields) {
      _validateDynamicFields(errors);
    } else {
      _validateAddress(
        _billingAddress,
        prefix: 'billing',
        requiresEmail: false,
        requiresPhone: true,
        errors: errors,
      );
      if (needsShipping && _shipToDifferentAddress) {
        _validateAddress(
          _shippingAddress,
          prefix: 'shipping',
          requiresEmail: false,
          requiresPhone: false,
          errors: errors,
        );
      }
    }
    if (needsPayment) {
      if (_paymentMethodId.isEmpty) {
        errors['paymentMethod'] = 'Choose a payment method.';
      } else if (!paymentMethodIds.contains(_paymentMethodId) ||
          !paymentMethodSupported(_paymentMethodId)) {
        errors['paymentMethod'] = 'This payment method is no longer available.';
      }
    }
    if (_customerNote.trim().length > 1000) {
      errors['customerNote'] = 'The order note is too long.';
    }

    if (errors.keys.any(_isBillingError)) _editingSavedAddress = true;
    _fieldErrors = Map<String, String>.unmodifiable(errors);
    _submitError = null;
    _notify();
    return errors.isEmpty;
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  Future<CheckoutOrderResult?> submit() {
    final Future<CheckoutOrderResult?>? active = _activeSubmission;
    if (active != null) {
      return active;
    }
    final Future<CheckoutOrderResult?> submission = _prepareAndSubmit();
    _activeSubmission = submission;
    submission.whenComplete(() {
      if (identical(_activeSubmission, submission)) {
        _activeSubmission = null;
      }
    });
    return submission;
  }

  Future<CheckoutOrderResult?> _prepareAndSubmit() async {
    if (_isDisposed ||
        _hasUnresolvedSubmission ||
        _status != CheckoutStatus.ready) {
      return null;
    }
    if (_checkout?.serverSafetyRequired == true &&
        _checkout?.serverSafetyEnforced != true) {
      _submitError =
          'The platform has not confirmed protected checkout. No order was sent.';
      _notify();
      return null;
    }
    final CartTotals? confirmedTotals = cart?.totals;
    _customerUpdateDebounce?.cancel();
    // Validate the complete local contract before asking WooCommerce to
    // recalculate shipping. Sending a partially entered address makes Store
    // API reveal one required field at a time as a global error.
    if (!validate()) {
      return null;
    }
    await _syncCustomerNow();
    if (_isDisposed ||
        _status != CheckoutStatus.ready ||
        _addressUpdateError != null ||
        _fieldErrors.isNotEmpty) {
      return null;
    }
    // Address synchronization can recalculate shipping, tax, discounts, or
    // currency after the buyer has pressed Place order. Never silently submit
    // an amount different from the one that was visible at that confirmation.
    if (!_sameConfirmedTotals(confirmedTotals, cart?.totals)) {
      _submitError =
          'Order totals or currency changed. Review the updated amount and confirm the order again.';
      _notify();
      return null;
    }
    if (!validate()) {
      return null;
    }
    if (supportsShippingQuotes && !shippingReady) {
      _submitError = 'Choose an available shipping option for this address.';
      _notify();
      return null;
    }
    return _performSubmit(confirmedTotals!);
  }

  bool _sameConfirmedTotals(CartTotals? confirmed, CartTotals? updated) {
    if (confirmed == null || updated == null) {
      return false;
    }
    return confirmed.priceMinor == updated.priceMinor &&
        confirmed.itemsMinor == updated.itemsMinor &&
        confirmed.itemsTaxMinor == updated.itemsTaxMinor &&
        confirmed.feesMinor == updated.feesMinor &&
        confirmed.feesTaxMinor == updated.feesTaxMinor &&
        confirmed.discountMinor == updated.discountMinor &&
        confirmed.discountTaxMinor == updated.discountTaxMinor &&
        confirmed.shippingMinor == updated.shippingMinor &&
        confirmed.shippingTaxMinor == updated.shippingTaxMinor &&
        confirmed.taxMinor == updated.taxMinor &&
        confirmed.currency.code == updated.currency.code &&
        confirmed.currency.minorUnit == updated.currency.minorUnit;
  }

  Future<CheckoutOrderResult?> _performSubmit(
    CartTotals confirmedTotals,
  ) async {
    CheckoutConfirmedTotal? confirmed;
    try {
      confirmed = CheckoutConfirmedTotal.fromCartTotals(confirmedTotals);
    } on FormatException {
      if (_checkout?.serverSafetyRequired == true) {
        _submitError = 'Review a valid exact order total before confirming.';
        _notify();
        return null;
      }
      // Older isolated host fixtures retain legacy validation behavior. The
      // configured Native path never sends an estimated or invalid amount.
    }
    _requestSerial++;
    _status = CheckoutStatus.submitting;
    _submitError = null;
    _notify();
    final String requestKey;
    try {
      requestKey = _pendingIdempotencyKey ??= _newIdempotencyKey();
    } catch (_) {
      _status = CheckoutStatus.ready;
      _submitError =
          'Unable to create a safe checkout attempt. No order was sent.';
      _notify();
      return null;
    }
    try {
      final CheckoutOrderResult result = await repository.placeOrder(
        CheckoutSubmission(
          billingAddress: _billingAddress.trimmed(),
          shippingAddress: _effectiveShippingAddress().trimmed(),
          customerNote: _customerNote.trim(),
          paymentMethodId: needsPayment ? _paymentMethodId : '',
          idempotencyKey: requestKey,
          confirmedTotal: confirmed,
          customFields: Map<String, String>.unmodifiable(<String, String>{
            for (final MapEntry<String, String> entry
                in _customFieldValues.entries)
              if (!_isCoreCheckoutField(entry.key))
                entry.key: entry.value.trim(),
          }),
        ),
      );
      if (_isDisposed) {
        return null;
      }
      _orderResult = result;
      _pendingIdempotencyKey = null;
      _status = CheckoutStatus.success;
      _notify();
      return result;
    } on CheckoutRepositoryException catch (error) {
      if (_isDisposed) {
        return null;
      }
      if (!_isKnownOrderRejection(error)) {
        _retainUnresolvedSubmission();
        return null;
      }
      // Only a known local/pre-dispatch validation rejection can start a new
      // attempt. A timeout, server error or unreadable response cannot.
      _pendingIdempotencyKey = null;
      if (error.confirmedPrePaymentRejection) {
        try {
          final CheckoutState current = await repository.loadCheckout();
          if (_isDisposed) return null;
          _checkout = current;
          if (current.hasUnresolvedSubmission) {
            _retainUnresolvedSubmission();
            return null;
          }
          // Preserve the buyer's current address draft, but calculate it on
          // the next explicit confirmation rather than posting while handling
          // this rejection. The new amount must then be confirmed again.
          _customerUpdateDirty = true;
          if (!paymentMethodIds.contains(_paymentMethodId)) {
            _paymentMethodId = paymentMethodIds.length == 1
                ? paymentMethodIds.single
                : '';
          }
        } on CheckoutRepositoryException catch (reloadError) {
          if (_isDisposed) return null;
          if (reloadError.requiresOutcomeRecovery) {
            _retainUnresolvedSubmission();
          } else {
            _commitLoadFailure(_requestSerial, reloadError.message);
          }
          return null;
        } catch (_) {
          if (!_isDisposed) {
            _commitLoadFailure(
              _requestSerial,
              'Unable to reload current checkout totals.',
            );
          }
          return null;
        }
      }
      if (error.authoritativeCart != null) {
        _applyAuthoritativeCart(error.authoritativeCart!);
      }
      final bool hasFieldErrors = _applyRepositoryFieldErrors(
        error.fieldErrors,
      );
      _submitError = hasFieldErrors
          ? null
          : (error.message.trim().isEmpty
                ? 'Unable to place this order.'
                : error.message.trim());
      _status = CheckoutStatus.ready;
      _notify();
      return null;
    } catch (_) {
      if (_isDisposed) {
        return null;
      }
      _retainUnresolvedSubmission();
      return null;
    }
  }

  bool _isKnownOrderRejection(CheckoutRepositoryException error) {
    if (error.requiresOutcomeRecovery) return false;
    if (error.confirmedPrePaymentRejection) return true;
    if (error.statusCode == null &&
        (error.kind == CheckoutFailureKind.invalidInput ||
            error.kind == CheckoutFailureKind.configuration)) {
      return true;
    }
    if (error.kind == CheckoutFailureKind.invalidInput &&
        (error.statusCode == 400 || error.statusCode == 422) &&
        error.fieldErrors.isNotEmpty) {
      return true;
    }
    return error.kind == CheckoutFailureKind.conflict &&
        error.statusCode == 409 &&
        error.authoritativeCart != null;
  }

  void _retainUnresolvedSubmission() {
    _hasUnresolvedSubmission = true;
    _customerUpdateDebounce?.cancel();
    _customerUpdateDirty = false;
    _submitError = _unresolvedOrderMessage;
    _status = CheckoutStatus.ready;
    _notify();
  }

  /// One explicit read-only recovery request. It can never replay a POST,
  /// dismiss a timeout, or use an order-history guess to unlock this customer.
  Future<CheckoutOrderResult?> recoverPendingOrder() {
    final Future<CheckoutOrderResult?>? active = _activeRecovery;
    if (active != null) return active;
    if (!canRecoverOrder || _activeSubmission != null) {
      return Future<CheckoutOrderResult?>.value();
    }
    final Future<CheckoutOrderResult?> operation = _recoverPendingOrder();
    _activeRecovery = operation;
    operation.whenComplete(() {
      if (identical(_activeRecovery, operation)) _activeRecovery = null;
    });
    return operation;
  }

  Future<CheckoutOrderResult?> _recoverPendingOrder() async {
    final int serial = ++_requestSerial;
    _isRecoveringOrder = true;
    _customerUpdateDebounce?.cancel();
    _customerUpdateDirty = false;
    _notify();
    try {
      final CheckoutAttemptRecovery recovery =
          await (repository as CheckoutRecoveryRepository)
              .recoverPendingOrder();
      if (!_canCommit(serial)) return null;
      if (!recovery.isResolved) {
        _retainUnresolvedSubmission();
        return null;
      }
      if (recovery.state == CheckoutRecoveryState.orderCreated) {
        _hasUnresolvedSubmission = false;
        _pendingIdempotencyKey = null;
        _submitError = null;
        _orderResult = recovery.orderResult;
        _status = CheckoutStatus.success;
        _notify();
        return recovery.orderResult;
      }
      // Exact server rejection before payment/stock allows a NEW explicit
      // confirmation, after rereading current totals. Keep the user's draft.
      _hasUnresolvedSubmission = false;
      _pendingIdempotencyKey = null;
      _status = CheckoutStatus.loading;
      _notify();
      final CheckoutState loaded = await repository.loadCheckout();
      if (!_canCommit(serial)) return null;
      _checkout = loaded;
      _hasUnresolvedSubmission = loaded.hasUnresolvedSubmission;
      if (!loaded.allowDifferentShippingAddress) {
        _shipToDifferentAddress = false;
      }
      _customerUpdateDirty = !_hasUnresolvedSubmission;
      if (!paymentMethodIds.contains(_paymentMethodId)) {
        _paymentMethodId = paymentMethodIds.length == 1
            ? paymentMethodIds.single
            : '';
      }
      _status = CheckoutStatus.ready;
      _submitError = _hasUnresolvedSubmission
          ? _unresolvedOrderMessage
          : 'The store confirmed that the previous attempt was rejected before payment. Review current totals and confirm again.';
      _notify();
    } on CheckoutRepositoryException catch (error) {
      if (!_canCommit(serial)) return null;
      if (_hasUnresolvedSubmission || error.requiresOutcomeRecovery) {
        _retainUnresolvedSubmission();
      } else {
        _commitLoadFailure(serial, error.message);
      }
    } catch (_) {
      if (!_canCommit(serial)) return null;
      if (_hasUnresolvedSubmission) {
        _retainUnresolvedSubmission();
      } else {
        _commitLoadFailure(serial, 'Unable to reload current checkout totals.');
      }
    } finally {
      if (!_isDisposed) {
        _isRecoveringOrder = false;
        _notify();
      }
    }
    return null;
  }

  void _scheduleCustomerUpdate() {
    if (_hasUnresolvedSubmission ||
        _status != CheckoutStatus.ready ||
        cart?.isEmpty != false) {
      return;
    }
    _addressRevision++;
    _customerUpdateDirty = true;
    _addressUpdateError = null;
    _customerUpdateDebounce?.cancel();
    _customerUpdateDebounce = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_syncCustomerNow()),
    );
    _notify();
  }

  Future<void> _syncCustomerNow() async {
    if (_hasUnresolvedSubmission) return;
    _customerUpdateDebounce?.cancel();
    final Future<void>? active = _activeCustomerUpdate;
    if (active != null) {
      await active;
      if (_customerUpdateDirty) {
        await _syncCustomerNow();
      }
      return;
    }
    if (!_customerUpdateDirty || _isDisposed || cart?.isEmpty != false) {
      return;
    }

    if (!supportsShippingQuotes && !_hasCompleteAddressForCustomerUpdate()) {
      // The next form edit marks the address dirty again. Avoid retaining a
      // queued partial update that would only produce another server error.
      _customerUpdateDirty = false;
      _addressUpdateError = null;
      _notify();
      return;
    }

    _customerUpdateDirty = false;
    final int serial = ++_customerUpdateSerial;
    final Future<void> operation = _performCustomerUpdate(serial);
    _activeCustomerUpdate = operation;
    try {
      await operation;
    } finally {
      if (identical(_activeCustomerUpdate, operation)) {
        _activeCustomerUpdate = null;
      }
    }
    if (_customerUpdateDirty) {
      await _syncCustomerNow();
    }
  }

  Future<void> _performCustomerUpdate(int serial) async {
    final int revision = _addressRevision;
    _isUpdatingCustomer = true;
    _addressUpdateError = null;
    _notify();
    try {
      final Cart updatedCart = supportsShippingQuotes
          ? await (repository as CheckoutShippingRepository).quoteShipping(
              billingAddress: _billingAddress.trimmed(),
              shippingAddress: _effectiveShippingAddress().trimmed(),
            )
          : await repository.updateCustomer(
              billingAddress: _billingAddress.trimmed(),
              shippingAddress: _effectiveShippingAddress().trimmed(),
            );
      if (_isDisposed ||
          serial != _customerUpdateSerial ||
          revision != _addressRevision) {
        return;
      }
      _quotedRevision = revision;
      _applyAuthoritativeCart(updatedCart);
    } on CheckoutRepositoryException catch (error) {
      if (_isDisposed ||
          serial != _customerUpdateSerial ||
          revision != _addressRevision) {
        return;
      }
      if (error.requiresOutcomeRecovery) {
        _retainUnresolvedSubmission();
        return;
      }
      if (error.authoritativeCart != null) {
        _applyAuthoritativeCart(error.authoritativeCart!);
      }
      final bool hasFieldErrors = _applyRepositoryFieldErrors(
        error.fieldErrors,
      );
      _addressUpdateError = hasFieldErrors
          ? null
          : (error.message.trim().isEmpty
                ? 'Unable to calculate shipping for this address.'
                : error.message.trim());
    } catch (_) {
      if (_isDisposed ||
          serial != _customerUpdateSerial ||
          revision != _addressRevision) {
        return;
      }
      _addressUpdateError = 'Unable to calculate shipping for this address.';
    } finally {
      if (!_isDisposed && serial == _customerUpdateSerial) {
        _isUpdatingCustomer = false;
        _notify();
      }
    }
  }

  Future<void> refreshShipping() async {
    if (!_canEditForm || _hasUnresolvedSubmission) return;
    _scheduleCustomerUpdate();
    await _syncCustomerNow();
  }

  Future<void> selectShippingRate(int packageId, String rateId) async {
    if (!_canEditForm ||
        !supportsShippingQuotes ||
        _hasUnresolvedSubmission ||
        !shippingQuoteCurrent) {
      return;
    }
    final matches = cart!.shippingPackages.where(
      (package) => package.id == packageId,
    );
    if (matches.length != 1 ||
        !matches.single.rates.any(
          (rate) => rate.id == rateId && !rate.selected,
        )) {
      return;
    }
    _isSelectingShipping = true;
    _addressUpdateError = null;
    _notify();
    try {
      final updated = await (repository as CheckoutShippingRepository)
          .selectShippingRate(packageId: packageId, rateId: rateId);
      if (!_isDisposed) _applyAuthoritativeCart(updated);
    } on CheckoutRepositoryException catch (error) {
      if (_isDisposed) return;
      if (error.requiresOutcomeRecovery) {
        _retainUnresolvedSubmission();
        return;
      }
      _addressUpdateError = error.message;
    } catch (_) {
      if (!_isDisposed) {
        _addressUpdateError = 'Unable to update shipping. Please try again.';
      }
    } finally {
      if (!_isDisposed) {
        _isSelectingShipping = false;
        _notify();
      }
    }
  }

  CheckoutAddress _effectiveShippingAddress() {
    if (!needsShipping || !_shipToDifferentAddress) {
      return _billingAddress;
    }
    return _shippingAddress.phone.trim().isEmpty
        ? _shippingAddress.copyWith(phone: _billingAddress.phone)
        : _shippingAddress;
  }

  bool _hasCompleteAddressForCustomerUpdate() {
    final Map<String, String> errors = <String, String>{};
    if (hasDynamicFields) {
      _validateDynamicFields(errors, addressOnly: true);
    } else {
      _validateAddress(
        _billingAddress,
        prefix: 'billing',
        requiresEmail: false,
        requiresPhone: true,
        errors: errors,
      );
      if (needsShipping && _shipToDifferentAddress) {
        _validateAddress(
          _effectiveShippingAddress(),
          prefix: 'shipping',
          requiresEmail: false,
          requiresPhone: true,
          errors: errors,
        );
      }
    }
    return errors.isEmpty;
  }

  void _applyAuthoritativeCart(Cart authoritativeCart) {
    _checkout = CheckoutState(
      cart: authoritativeCart,
      savedAddresses: _checkout?.savedAddresses ?? const [],
      nativePaymentAdapters: _checkout?.nativePaymentAdapters ?? const {},
      allowDifferentShippingAddress:
          _checkout?.allowDifferentShippingAddress ?? false,
      hasUnresolvedSubmission: _hasUnresolvedSubmission,
      serverSafetyRequired: _checkout?.serverSafetyRequired ?? false,
      serverSafetyEnforced: _checkout?.serverSafetyEnforced ?? false,
      paymentMethodLabels:
          _checkout?.paymentMethodLabels ?? const <String, String>{},
      fieldDefinitions:
          _checkout?.fieldDefinitions ?? const <CheckoutFieldDefinition>[],
    );
    if (!paymentMethodIds.contains(_paymentMethodId)) {
      _paymentMethodId = paymentMethodIds.length == 1
          ? paymentMethodIds.single
          : '';
    }
  }

  void _applyDefaultCountries(List<CheckoutFieldDefinition> definitions) {
    String defaultFor(String key) {
      for (final CheckoutFieldDefinition field in definitions) {
        if (field.key == key && field.defaultValue.trim().isNotEmpty) {
          return field.defaultValue.trim().toUpperCase();
        }
      }
      return '';
    }

    final String billingCountry = _billingAddress.country.trim().isNotEmpty
        ? _billingAddress.country.trim().toUpperCase()
        : (defaultFor('billing_country').isNotEmpty
              ? defaultFor('billing_country')
              : '');
    final String shippingCountry = _shippingAddress.country.trim().isNotEmpty
        ? _shippingAddress.country.trim().toUpperCase()
        : (defaultFor('shipping_country').isNotEmpty
              ? defaultFor('shipping_country')
              : billingCountry);
    _billingAddress = _billingAddress.copyWith(country: billingCountry);
    _shippingAddress = _shippingAddress.copyWith(country: shippingCountry);
  }

  void _applyDefaultAddresses(List<CheckoutFieldDefinition> fields) {
    final defaults = {
      for (final field in fields) field.key: field.defaultValue,
    };
    CheckoutAddress fill(CheckoutAddress address, String prefix) {
      String value(String key, String current) => current.trim().isNotEmpty
          ? current
          : defaults['${prefix}_$key'] ?? current;
      return address.copyWith(
        firstName: value('first_name', address.firstName),
        lastName: value('last_name', address.lastName),
        company: value('company', address.company),
        address1: value('address_1', address.address1),
        address2: value('address_2', address.address2),
        city: value('city', address.city),
        state: value('state', address.state),
        postcode: value('postcode', address.postcode),
        country: value('country', address.country),
        email: value('email', address.email),
        phone: value('phone', address.phone),
      );
    }

    _billingAddress = fill(_billingAddress, 'billing');
    _shippingAddress = fill(_shippingAddress, 'shipping');
  }

  void _validateAddress(
    CheckoutAddress source, {
    required String prefix,
    required bool requiresEmail,
    required bool requiresPhone,
    required Map<String, String> errors,
  }) {
    final CheckoutAddress address = source.trimmed();
    void requiredField(String name, String value, String message) {
      if (value.isEmpty) {
        errors['$prefix.$name'] = message;
      }
    }

    requiredField('firstName', address.firstName, 'First name is required.');
    requiredField('lastName', address.lastName, 'Last name is required.');
    requiredField('address1', address.address1, 'Street address is required.');
    requiredField('city', address.city, 'City is required.');
    requiredField('country', address.country, 'Country code is required.');
    final Map<String, String> states = CheckoutCountryData.statesFor(
      address.country,
    );
    if (states.isNotEmpty && !states.containsKey(address.state)) {
      errors['$prefix.state'] = 'Choose a valid state.';
    }
    if (address.country.isNotEmpty &&
        !RegExp(r'^[A-Za-z]{2}$').hasMatch(address.country)) {
      errors['$prefix.country'] = 'Use a two-letter country code.';
    }
    if (requiresEmail) {
      requiredField('email', address.email, 'Email is required.');
      if (address.email.isNotEmpty &&
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address.email)) {
        errors['$prefix.email'] = 'Enter a valid email address.';
      }
    }
    if (requiresPhone) {
      requiredField('phone', address.phone, 'Phone is required.');
    }
  }

  void _validateDynamicFields(
    Map<String, String> errors, {
    bool addressOnly = false,
  }) {
    final List<CheckoutFieldDefinition> definitions =
        _checkout?.fieldDefinitions ?? const <CheckoutFieldDefinition>[];
    for (final definition in definitions) {
      final field = _fieldForCurrentCountry(definition);
      if (!field.isVisible ||
          (addressOnly && !_isCoreAddressField(field.key)) ||
          (field.group == CheckoutFieldGroup.shipping && !needsShipping) ||
          (addressOnly && field.group == CheckoutFieldGroup.order)) {
        continue;
      }

      String errorKey = field.key;
      String value = valueForField(field).trim();
      if (field.group == CheckoutFieldGroup.shipping &&
          !_shipToDifferentAddress) {
        final String? billingKey = _billingKeyForShippingField(field.key);
        if (billingKey == null ||
            !definitions.any((f) => f.key == billingKey)) {
          // Classic checkout does not require shipping-only custom fields
          // when one address is used for billing and shipping.
          continue;
        }
        errorKey = billingKey;
        value = _valueForKey(billingKey, fallback: field.defaultValue).trim();
      }
      if (field.required &&
          (value.isEmpty ||
              (field.type == CheckoutFieldType.checkbox && value != '1'))) {
        errors.putIfAbsent(errorKey, () => '${field.label} is required.');
        continue;
      }
      if (value.isNotEmpty &&
          field.type == CheckoutFieldType.email &&
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
        errors.putIfAbsent(errorKey, () => 'Enter a valid email address.');
        continue;
      }
      if (value.isNotEmpty &&
          field.type == CheckoutFieldType.select &&
          field.options.isNotEmpty &&
          !field.options.containsKey(value)) {
        errors.putIfAbsent(errorKey, () => 'Choose a valid option.');
      }
    }
  }

  String? _billingKeyForShippingField(String key) {
    if (!key.startsWith('shipping_')) {
      return null;
    }
    final String billingKey = 'billing_${key.substring('shipping_'.length)}';
    return _isCoreAddressField(billingKey) ? billingKey : null;
  }

  static bool _isCoreAddressField(String key) =>
      (key.startsWith('billing_') || key.startsWith('shipping_')) &&
      _isCoreCheckoutField(key) &&
      key != 'billing_email' &&
      key != 'shipping_email';

  String _valueForKey(String key, {String fallback = ''}) {
    return switch (key) {
      'billing_first_name' => _billingAddress.firstName,
      'billing_last_name' => _billingAddress.lastName,
      'billing_company' => _billingAddress.company,
      'billing_address_1' => _billingAddress.address1,
      'billing_address_2' => _billingAddress.address2,
      'billing_city' => _billingAddress.city,
      'billing_state' => _billingAddress.state,
      'billing_postcode' => _billingAddress.postcode,
      'billing_country' => _billingAddress.country,
      'billing_email' => _billingAddress.email,
      'billing_phone' => _billingAddress.phone,
      'shipping_first_name' => _shippingAddress.firstName,
      'shipping_last_name' => _shippingAddress.lastName,
      'shipping_company' => _shippingAddress.company,
      'shipping_address_1' => _shippingAddress.address1,
      'shipping_address_2' => _shippingAddress.address2,
      'shipping_city' => _shippingAddress.city,
      'shipping_state' => _shippingAddress.state,
      'shipping_postcode' => _shippingAddress.postcode,
      'shipping_country' => _shippingAddress.country,
      'shipping_email' => _shippingAddress.email,
      'shipping_phone' => _shippingAddress.phone,
      'order_comments' => _customerNote,
      _ => _customFieldValues[key] ?? fallback,
    };
  }

  static bool _isCoreCheckoutField(String key) {
    return <String>{
      'billing_first_name',
      'billing_last_name',
      'billing_company',
      'billing_address_1',
      'billing_address_2',
      'billing_city',
      'billing_state',
      'billing_postcode',
      'billing_country',
      'billing_email',
      'billing_phone',
      'shipping_first_name',
      'shipping_last_name',
      'shipping_company',
      'shipping_address_1',
      'shipping_address_2',
      'shipping_city',
      'shipping_state',
      'shipping_postcode',
      'shipping_country',
      'shipping_email',
      'shipping_phone',
      'order_comments',
    }.contains(key);
  }

  bool _applyRepositoryFieldErrors(Map<String, String> serverErrors) {
    if (serverErrors.isEmpty) {
      return false;
    }
    final Set<String> visibleDynamicKeys = <String>{
      for (final CheckoutFieldDefinition field
          in _checkout?.fieldDefinitions ?? const <CheckoutFieldDefinition>[])
        if (field.isVisible) field.key,
    };
    final Map<String, String> mapped = <String, String>{};
    for (final MapEntry<String, String> entry in serverErrors.entries) {
      String? key;
      if (hasDynamicFields) {
        if (!_shipToDifferentAddress && entry.key.startsWith('shipping_')) {
          final String? billingKey = _billingKeyForShippingField(entry.key);
          if (billingKey != null && visibleDynamicKeys.contains(billingKey)) {
            key = billingKey;
          }
        } else if (visibleDynamicKeys.contains(entry.key)) {
          key = entry.key;
        }
      } else {
        final String effectiveKey =
            !_shipToDifferentAddress && entry.key.startsWith('shipping_')
            ? 'billing_${entry.key.substring('shipping_'.length)}'
            : entry.key;
        key = _builtInFieldKey(effectiveKey);
      }
      if (key != null) {
        mapped.putIfAbsent(key, () => entry.value);
      }
    }
    if (mapped.isEmpty) {
      return false;
    }
    if (mapped.keys.any(_isBillingError)) _editingSavedAddress = true;
    _fieldErrors = Map<String, String>.unmodifiable(<String, String>{
      ..._fieldErrors,
      ...mapped,
    });
    return true;
  }

  String? _builtInFieldKey(String key) {
    return switch (key) {
      'billing_first_name' => 'billing.firstName',
      'billing_last_name' => 'billing.lastName',
      'billing_company' => 'billing.company',
      'billing_address_1' => 'billing.address1',
      'billing_address_2' => 'billing.address2',
      'billing_city' => 'billing.city',
      'billing_state' => 'billing.state',
      'billing_postcode' => 'billing.postcode',
      'billing_country' => 'billing.country',
      'billing_phone' => 'billing.phone',
      'shipping_first_name' => 'shipping.firstName',
      'shipping_last_name' => 'shipping.lastName',
      'shipping_company' => 'shipping.company',
      'shipping_address_1' => 'shipping.address1',
      'shipping_address_2' => 'shipping.address2',
      'shipping_city' => 'shipping.city',
      'shipping_state' => 'shipping.state',
      'shipping_postcode' => 'shipping.postcode',
      'shipping_country' => 'shipping.country',
      'shipping_phone' => 'shipping.phone',
      _ => null,
    };
  }

  void _onFormChanged(String fieldPrefix) {
    if (!_hasUnresolvedSubmission) {
      _pendingIdempotencyKey = null;
      _submitError = null;
    }
    _orderResult = null;
    if (_fieldErrors.isNotEmpty) {
      _fieldErrors = Map<String, String>.unmodifiable(<String, String>{
        for (final MapEntry<String, String> entry in _fieldErrors.entries)
          if (!entry.key.startsWith(fieldPrefix)) entry.key: entry.value,
      });
    }
    if (_status == CheckoutStatus.success) {
      _status = CheckoutStatus.ready;
    }
    _notify();
  }

  bool get _canEditForm =>
      !_isDisposed &&
      !_isRecoveringOrder &&
      !_isSelectingShipping &&
      _status != CheckoutStatus.submitting &&
      _status != CheckoutStatus.success;

  String _newIdempotencyKey() {
    _submissionSequence++;
    if (_checkout?.serverSafetyRequired == true) {
      // Independent devices/processes can have identical clocks and local
      // counters. Protect a new explicit confirmation with fresh 128-bit
      // entropy rather than accidentally colliding with another buyer attempt.
      final Random random = Random.secure();
      final String entropy = List<String>.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      return 'checkout-${_clock().microsecondsSinceEpoch}-$_submissionSequence-$entropy';
    }
    return 'checkout-${_clock().microsecondsSinceEpoch}-$_submissionSequence';
  }

  void _commitLoadFailure(int serial, String message) {
    if (!_canCommit(serial)) {
      return;
    }
    _checkout = null;
    _loadError = message.trim().isEmpty
        ? 'Unable to load checkout. Please try again.'
        : message.trim();
    _status = CheckoutStatus.failure;
    _notify();
  }

  bool _hasAddress(CheckoutAddress address) {
    return address.firstName.trim().isNotEmpty ||
        address.lastName.trim().isNotEmpty ||
        address.company.trim().isNotEmpty ||
        address.address1.trim().isNotEmpty ||
        address.address2.trim().isNotEmpty ||
        address.city.trim().isNotEmpty ||
        address.state.trim().isNotEmpty ||
        address.postcode.trim().isNotEmpty ||
        address.phone.trim().isNotEmpty;
  }

  bool _sameAddress(CheckoutAddress left, CheckoutAddress right) {
    final CheckoutAddress first = left.trimmed();
    final CheckoutAddress second = right.trimmed();
    return first.firstName == second.firstName &&
        first.lastName == second.lastName &&
        first.company == second.company &&
        first.address1 == second.address1 &&
        first.address2 == second.address2 &&
        first.city == second.city &&
        first.state == second.state &&
        first.postcode == second.postcode &&
        first.country == second.country;
  }

  bool _canCommit(int serial) => !_isDisposed && serial == _requestSerial;

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _customerUpdateDebounce?.cancel();
    _customerUpdateSerial++;
    _requestSerial++;
    super.dispose();
  }
}
