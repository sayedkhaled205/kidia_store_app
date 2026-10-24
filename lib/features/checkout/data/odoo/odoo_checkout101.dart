import '../../../../core/commerce/odoo_customer_client51.dart';
import '../../../cart/data/odoo/odoo_cart85.dart';

class OdooAddressField101 {
  OdooAddressField101(Map<String, dynamic> raw)
    : name = text85(raw['name']),
      label = text85(raw['label']),
      kind = text85(raw['kind']),
      value = text85(raw['value'], maximum: 254),
      required = bool85(raw['required']),
      readonly = bool85(raw['readonly']),
      choices = _choices(raw['choices']) {
    if (!const {
          'name',
          'email',
          'phone',
          'street',
          'street2',
          'city',
          'zip',
          'country_id',
          'state_id',
          'company_name',
          'vat',
        }.contains(name) ||
        !const {'text', 'email', 'tel', 'select'}.contains(kind) ||
        label.isEmpty ||
        (kind != 'select' && choices.isNotEmpty) ||
        (kind == 'select' && value.isNotEmpty && !choices.containsKey(value))) {
      throw const FormatException('Invalid merchant address field.');
    }
  }
  final String name, label, kind, value;
  final bool required, readonly;
  final Map<String, String> choices;
  static Map<String, String> _choices(Object? raw) {
    if (raw is! List || raw.length > 1000) {
      throw const FormatException('Invalid choices.');
    }
    final result = <String, String>{};
    for (final item in raw) {
      final choice = object85(item);
      final value = text85(choice['value']);
      final label = text85(choice['label']);
      if (!RegExp(r'^[1-9][0-9]{0,9}$').hasMatch(value) ||
          result.containsKey(value) ||
          label.isEmpty) {
        throw const FormatException('Invalid choice identity.');
      }
      result[value] = label;
    }
    return Map.unmodifiable(result);
  }
}

class OdooAddressForm101 {
  OdooAddressForm101.fromResponse(Map<String, dynamic> response, this.cart)
    : addressType = text85(response['address_type']),
      separateShippingAllowed = bool85(response['separate_shipping_allowed']),
      useSameAddress = bool85(response['use_same_address']),
      fields = _fields(response['fields']) {
    if (response['checkout_form_contract_version'] != '101.1' ||
        !const {'billing', 'delivery'}.contains(addressType)) {
      throw const FormatException('Unverified address form.');
    }
  }
  final String addressType;
  final bool separateShippingAllowed, useSameAddress;
  final List<OdooAddressField101> fields;
  final OdooCart85 cart;
  static List<OdooAddressField101> _fields(Object? raw) {
    if (raw is! List || raw.isEmpty || raw.length > 20) {
      throw const FormatException('Invalid fields.');
    }
    final fields = raw.map((v) => OdooAddressField101(object85(v))).toList();
    if (fields.map((f) => f.name).toSet().length != fields.length) {
      throw const FormatException('Duplicate fields.');
    }
    return List.unmodifiable(fields);
  }
}

class OdooShippingRate101 {
  OdooShippingRate101(Map<String, dynamic> raw)
    : id = int85(raw['carrier_id'], minimum: 1),
      name = text85(raw['name']),
      amount = minor85(raw['display_price_minor']),
      selected = bool85(raw['selected']),
      estimated = bool85(raw['estimated']) {
    minor85(raw['price_minor']);
    minor85(raw['tax_minor']);
    if (name.isEmpty) throw const FormatException('Invalid carrier name.');
  }
  final int id;
  final String name, amount;
  final bool selected, estimated;
}

class OdooShipping101 {
  OdooShipping101.fromResponse(Map<String, dynamic> response, this.cart)
    : rates = _rates(response) {
    if (rates.where((r) => r.selected).length > 1 ||
        (!cart.cart.needsShipping && rates.isNotEmpty)) {
      throw const FormatException('Invalid delivery selection.');
    }
  }
  final OdooCart85 cart;
  final List<OdooShippingRate101> rates;
  static List<OdooShippingRate101> _rates(Map<String, dynamic> response) {
    final raw = response['shipping_rates'];
    if (response['shipping_contract_version'] != '100.1' ||
        raw is! List ||
        raw.length > 100) {
      throw const FormatException('Unverified shipping response.');
    }
    final rates = raw.map((r) => OdooShippingRate101(object85(r))).toList();
    if (rates.map((r) => r.id).toSet().length != rates.length) {
      throw const FormatException('Duplicate carrier.');
    }
    return List.unmodifiable(rates);
  }
}

/// One checkout owner, never rebound to a subsequent account after logout.
abstract interface class OdooCheckoutApi101 {
  Future<OdooAddressForm101> form({String type = 'billing', int? countryId});
  Future<OdooShipping101> save({
    required String type,
    required Map<String, String> fields,
    required bool useForShipping,
  });
  Future<OdooShipping101> quote();
  Future<OdooShipping101> select(int id, String revision);
}

class OdooCheckout101 implements OdooCheckoutApi101 {
  OdooCheckout101(this.client, {required this.isCurrent})
    : _epoch = client.sessionEpoch85,
      _uid = client.customer?.id;
  final OdooCustomerClient51 client;
  final bool Function() isCurrent;
  final int _epoch;
  final int? _uid;
  void _check() {
    if (!isCurrent() ||
        _epoch != client.sessionEpoch85 ||
        _uid != client.customer?.id) {
      throw const OdooCustomerException51('customer_session_changed');
    }
  }

  Future<Map<String, dynamic>> _run(
    Future<Map<String, dynamic>> Function() action,
  ) async {
    _check();
    final result = await action();
    _check();
    return result;
  }

  OdooCart85 _cart(Map<String, dynamic> raw) =>
      OdooCart85.fromResponse(raw, customerId: _uid, origin: client.origin);
  @override
  Future<OdooAddressForm101> form({
    String type = 'billing',
    int? countryId,
  }) async {
    final raw = await _run(
      () => client.checkoutForm101(addressType: type, countryId: countryId),
    );
    final result = OdooAddressForm101.fromResponse(raw, _cart(raw));
    if (result.addressType != type) {
      throw const FormatException('Different address type.');
    }
    return result;
  }

  @override
  Future<OdooShipping101> save({
    required String type,
    required Map<String, String> fields,
    required bool useForShipping,
  }) async {
    final raw = await _run(
      () => client.saveCheckoutAddress101(
        addressType: type,
        fields: fields,
        useForShipping: useForShipping,
      ),
    );
    return OdooShipping101.fromResponse(raw, _cart(raw));
  }

  @override
  Future<OdooShipping101> quote() async {
    final raw = await _run(client.shippingQuote101);
    return OdooShipping101.fromResponse(raw, _cart(raw));
  }

  @override
  Future<OdooShipping101> select(int id, String revision) async {
    final raw = await _run(
      () => client.selectShipping101(carrierId: id, revision: revision),
    );
    final result = OdooShipping101.fromResponse(raw, _cart(raw));
    if (!result.rates.any((r) => r.id == id && r.selected)) {
      throw const FormatException('Carrier not selected.');
    }
    return result;
  }
}
