import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart.dart';
import 'package:kidia_store_app/features/checkout/data/models/checkout_country_data.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_address.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_field_definition.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_order_result.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_submission.dart';
import 'package:kidia_store_app/features/checkout/domain/repositories/checkout_repository.dart';

enum CheckoutStatus { initial, loading, ready, submitting, success, failure }

class CheckoutController extends ChangeNotifier {
  CheckoutController({required this.repository, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final CheckoutRepository repository;
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
  Future<void>? _activeCustomerUpdate;
  Timer? _customerUpdateDebounce;
  String? _pendingIdempotencyKey;
  String? _addressUpdateError;
  int _submissionSequence = 0;
  int _requestSerial = 0;
  int _customerUpdateSerial = 0;
  bool _customerUpdateDirty = false;
  bool _isUpdatingCustomer = false;
  bool _isDisposed = false;

  CheckoutStatus get status => _status;
  CheckoutState? get checkout => _checkout;
  Cart? get cart => _checkout?.cart;
  CheckoutAddress get billingAddress => _billingAddress;
  CheckoutAddress get shippingAddress => _shippingAddress;
  bool get shipToDifferentAddress => _shipToDifferentAddress;
  String get customerNote => _customerNote;
  String get paymentMethodId => _paymentMethodId;
  List<String> get paymentMethodIds =>
      _checkout?.paymentMethodIds ?? const <String>[];
  Map<String, String> get fieldErrors =>
      UnmodifiableMapView<String, String>(_fieldErrors);
  String? get loadError => _loadError;
  String? get submitError => _submitError;
  String? get addressUpdateError => _addressUpdateError;
  CheckoutOrderResult? get orderResult => _orderResult;
  bool get isSubmitting => _status == CheckoutStatus.submitting;
  bool get isUpdatingCustomer => _isUpdatingCustomer;
  bool get needsPayment => _checkout?.needsPayment ?? false;
  bool get needsShipping => _checkout?.needsShipping ?? false;
  bool get hasDynamicFields => _checkout?.hasDynamicFields ?? false;
  bool get canSubmit =>
      _status == CheckoutStatus.ready && cart?.isEmpty == false;

  String? errorFor(String field) => _fieldErrors[field];

  List<CheckoutFieldDefinition> fieldsFor(CheckoutFieldGroup group) {
    return List<CheckoutFieldDefinition>.unmodifiable(
      (_checkout?.fieldDefinitions ?? const <CheckoutFieldDefinition>[]).where(
        (CheckoutFieldDefinition field) =>
            field.group == group && field.isVisible,
      ),
    );
  }

  String valueForField(CheckoutFieldDefinition field) {
    return _valueForKey(field.key, fallback: field.defaultValue);
  }

  Future<void> load() async {
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
      _shippingAddress = CheckoutAddress.fromCartAddress(
        loaded.cart.shippingAddress,
      );
      _applyDefaultCountries(loaded.fieldDefinitions);
      _shipToDifferentAddress =
          loaded.needsShipping &&
          _hasAddress(_shippingAddress) &&
          !_sameAddress(_billingAddress, _shippingAddress);
      _paymentMethodId = loaded.paymentMethodIds.length == 1
          ? loaded.paymentMethodIds.single
          : '';
      _customerNote = '';
      _customFieldValues = <String, String>{
        for (final CheckoutFieldDefinition field in loaded.fieldDefinitions)
          if (!_isCoreCheckoutField(field.key) && field.defaultValue.isNotEmpty)
            field.key: field.defaultValue,
      };
      _pendingIdempotencyKey = null;
      _addressUpdateError = null;
      _customerUpdateDirty = false;
      _orderResult = null;
      _status = CheckoutStatus.ready;
      _notify();
    } on CheckoutRepositoryException catch (error) {
      _commitLoadFailure(serial, error.message);
    } catch (_) {
      _commitLoadFailure(serial, 'Unable to load checkout. Please try again.');
    }
  }

  void updateBillingAddress(CheckoutAddress address) {
    _billingAddress = address;
    _onFormChanged('billing.');
    _scheduleCustomerUpdate();
  }

  void updateShippingAddress(CheckoutAddress address) {
    _shippingAddress = address;
    _onFormChanged('shipping.');
    _scheduleCustomerUpdate();
  }

  void setShipToDifferentAddress(bool value) {
    if (_shipToDifferentAddress == value) {
      return;
    }
    _shipToDifferentAddress = value;
    _onFormChanged('shipping.');
    _scheduleCustomerUpdate();
  }

  void setCustomerNote(String value) {
    if (_customerNote == value) {
      return;
    }
    _customerNote = value;
    _onFormChanged('customerNote');
  }

  void setPaymentMethod(String value) {
    final String method = value.trim();
    if (_paymentMethodId == method) {
      return;
    }
    _paymentMethodId = method;
    _onFormChanged('paymentMethod');
  }

  void setFieldValue(String key, String value) {
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
        _billingAddress = _billingAddress.copyWith(country: value);
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
        _shippingAddress = _shippingAddress.copyWith(country: value);
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
    _onFormChanged(fieldKey);
    if (fieldKey.startsWith('billing_') || fieldKey.startsWith('shipping_')) {
      _scheduleCustomerUpdate();
    }
  }

  bool validate() {
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
      } else if (!paymentMethodIds.contains(_paymentMethodId)) {
        errors['paymentMethod'] = 'This payment method is no longer available.';
      }
    }
    if (_customerNote.trim().length > 1000) {
      errors['customerNote'] = 'The order note is too long.';
    }

    _fieldErrors = Map<String, String>.unmodifiable(errors);
    _submitError = null;
    _notify();
    return errors.isEmpty;
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
    if (_status != CheckoutStatus.ready) {
      return null;
    }
    _customerUpdateDebounce?.cancel();
    // Validate the complete local contract before asking WooCommerce to
    // recalculate shipping. Sending a partially entered address makes Store
    // API reveal one required field at a time as a global error.
    if (!validate()) {
      return null;
    }
    await _syncCustomerNow();
    if (_status != CheckoutStatus.ready ||
        _addressUpdateError != null ||
        _fieldErrors.isNotEmpty) {
      return null;
    }
    return _performSubmit();
  }

  Future<CheckoutOrderResult?> _performSubmit() async {
    _requestSerial++;
    _status = CheckoutStatus.submitting;
    _submitError = null;
    _notify();
    final String requestKey = _pendingIdempotencyKey ??= _newIdempotencyKey();
    try {
      final CheckoutOrderResult result = await repository.placeOrder(
        CheckoutSubmission(
          billingAddress: _billingAddress.trimmed(),
          shippingAddress: _effectiveShippingAddress().trimmed(),
          customerNote: _customerNote.trim(),
          paymentMethodId: needsPayment ? _paymentMethodId : '',
          idempotencyKey: requestKey,
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
      _submitError = 'Unable to place this order. Please try again.';
      _status = CheckoutStatus.ready;
      _notify();
      return null;
    }
  }

  void _scheduleCustomerUpdate() {
    if (_status != CheckoutStatus.ready || cart?.isEmpty != false) {
      return;
    }
    _customerUpdateDirty = true;
    _addressUpdateError = null;
    _customerUpdateDebounce?.cancel();
    _customerUpdateDebounce = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(_syncCustomerNow()),
    );
  }

  Future<void> _syncCustomerNow() async {
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

    if (!_hasCompleteAddressForCustomerUpdate()) {
      // The next form edit marks the address dirty again. Avoid retaining a
      // queued partial update that would only produce another server error.
      _customerUpdateDirty = false;
      _addressUpdateError = null;
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
    _isUpdatingCustomer = true;
    _addressUpdateError = null;
    _notify();
    try {
      final Cart updatedCart = await repository.updateCustomer(
        billingAddress: _billingAddress.trimmed(),
        shippingAddress: _effectiveShippingAddress().trimmed(),
      );
      if (_isDisposed || serial != _customerUpdateSerial) {
        return;
      }
      _applyAuthoritativeCart(updatedCart);
    } on CheckoutRepositoryException catch (error) {
      if (_isDisposed || serial != _customerUpdateSerial) {
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
      if (_isDisposed || serial != _customerUpdateSerial) {
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
              : 'EG');
    final String shippingCountry = _shippingAddress.country.trim().isNotEmpty
        ? _shippingAddress.country.trim().toUpperCase()
        : (defaultFor('shipping_country').isNotEmpty
              ? defaultFor('shipping_country')
              : billingCountry);
    _billingAddress = _billingAddress.copyWith(country: billingCountry);
    _shippingAddress = _shippingAddress.copyWith(country: shippingCountry);
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
    for (final CheckoutFieldDefinition field in definitions) {
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
        if (billingKey == null) {
          // Classic checkout does not require shipping-only custom fields
          // when one address is used for billing and shipping.
          continue;
        }
        errorKey = billingKey;
        value = _valueForKey(
          billingKey,
          fallback: field.defaultValue,
        ).trim();
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
        final String effectiveKey = !_shipToDifferentAddress &&
                entry.key.startsWith('shipping_')
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
    _pendingIdempotencyKey = null;
    _submitError = null;
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

  String _newIdempotencyKey() {
    _submissionSequence++;
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
