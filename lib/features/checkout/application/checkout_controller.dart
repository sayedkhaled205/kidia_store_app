import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart.dart';
import 'package:kidia_store_app/features/checkout/domain/entities/checkout_address.dart';
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
  Map<String, String> _fieldErrors = const <String, String>{};
  String? _loadError;
  String? _submitError;
  CheckoutOrderResult? _orderResult;
  Future<CheckoutOrderResult?>? _activeSubmission;
  String? _pendingIdempotencyKey;
  int _submissionSequence = 0;
  int _requestSerial = 0;
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
  CheckoutOrderResult? get orderResult => _orderResult;
  bool get isSubmitting => _status == CheckoutStatus.submitting;
  bool get needsPayment => _checkout?.needsPayment ?? false;
  bool get needsShipping => _checkout?.needsShipping ?? false;
  bool get canSubmit =>
      _status == CheckoutStatus.ready && cart?.isEmpty == false;

  String? errorFor(String field) => _fieldErrors[field];

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
      _shipToDifferentAddress =
          loaded.needsShipping &&
          _hasAddress(_shippingAddress) &&
          !_sameAddress(_billingAddress, _shippingAddress);
      _paymentMethodId = loaded.paymentMethodIds.length == 1
          ? loaded.paymentMethodIds.single
          : '';
      _customerNote = '';
      _pendingIdempotencyKey = null;
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
  }

  void updateShippingAddress(CheckoutAddress address) {
    _shippingAddress = address;
    _onFormChanged('shipping.');
  }

  void setShipToDifferentAddress(bool value) {
    if (_shipToDifferentAddress == value) {
      return;
    }
    _shipToDifferentAddress = value;
    _onFormChanged('shipping.');
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

  bool validate() {
    final Map<String, String> errors = <String, String>{};
    final Cart? currentCart = cart;
    if (currentCart == null || currentCart.isEmpty) {
      errors['cart'] = 'Your cart is empty.';
    }

    _validateAddress(
      _billingAddress,
      prefix: 'billing',
      requiresEmail: true,
      errors: errors,
    );
    if (needsShipping && _shipToDifferentAddress) {
      _validateAddress(
        _shippingAddress,
        prefix: 'shipping',
        requiresEmail: false,
        errors: errors,
      );
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
    if (_status != CheckoutStatus.ready || !validate()) {
      return Future<CheckoutOrderResult?>.value(null);
    }
    final Future<CheckoutOrderResult?> submission = _performSubmit();
    _activeSubmission = submission;
    return submission;
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
      _submitError = error.message.trim().isEmpty
          ? 'Unable to place this order.'
          : error.message.trim();
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
    } finally {
      _activeSubmission = null;
    }
  }

  CheckoutAddress _effectiveShippingAddress() {
    if (!needsShipping || !_shipToDifferentAddress) {
      return _billingAddress;
    }
    return _shippingAddress;
  }

  void _applyAuthoritativeCart(Cart authoritativeCart) {
    _checkout = CheckoutState(cart: authoritativeCart);
    if (!paymentMethodIds.contains(_paymentMethodId)) {
      _paymentMethodId = paymentMethodIds.length == 1
          ? paymentMethodIds.single
          : '';
    }
  }

  void _validateAddress(
    CheckoutAddress source, {
    required String prefix,
    required bool requiresEmail,
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
        address.address1.trim().isNotEmpty ||
        address.city.trim().isNotEmpty ||
        address.country.trim().isNotEmpty;
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
    _requestSerial++;
    super.dispose();
  }
}
