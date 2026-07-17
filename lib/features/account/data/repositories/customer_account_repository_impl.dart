import 'package:kidia_store_app/features/account/data/network/customer_account_api_transport.dart';
import 'package:kidia_store_app/features/account/domain/entities/customer_account.dart';
import 'package:kidia_store_app/features/account/domain/repositories/customer_account_repository.dart';

class CustomerAccountRepositoryImpl implements CustomerAccountRepository {
  const CustomerAccountRepositoryImpl(this.transport);

  final CustomerAccountApiTransport transport;

  @override
  Future<CustomerAccount> getAccount() async {
    try {
      final Map<String, dynamic> account = await transport.fetchAccount();
      Map<String, dynamic>? configuration;
      try {
        configuration = await transport.fetchAddressConfig();
      } catch (_) {
        // Account data must remain available when an older plugin does not yet
        // expose the dynamic checkout-field contract.
      }
      return _account(account, configuration);
    } on CustomerAccountTransportException catch (error, stackTrace) {
      Error.throwWithStackTrace(_transportFailure(error), stackTrace);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CustomerAccountRepositoryException(
          kind: CustomerAccountFailureKind.invalidResponse,
          message: 'The store returned invalid customer account data.',
          cause: error,
        ),
        stackTrace,
      );
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CustomerAccountRepositoryException(
          kind: CustomerAccountFailureKind.unknown,
          message: 'Unable to load the customer account.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<CustomerProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String displayName,
    required String email,
    required String phone,
    required String alternatePhone,
  }) async {
    try {
      final Map<String, dynamic> response = await transport.updateProfile(
        <String, String>{
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'display_name': displayName.trim(),
          'email': email.trim(),
          'phone': phone.trim(),
          'alternate_phone': alternatePhone.trim(),
        },
      );
      return _profile(_object(response['profile'], 'profile'));
    } on CustomerAccountTransportException catch (error, stackTrace) {
      Error.throwWithStackTrace(_transportFailure(error), stackTrace);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CustomerAccountRepositoryException(
          kind: CustomerAccountFailureKind.invalidResponse,
          message: 'The store returned invalid customer profile data.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<CustomerAddress> updateAddress(CustomerAddress address) async {
    try {
      final String prefix = address.type == CustomerAddressType.billing
          ? 'billing'
          : 'shipping';
      final Map<String, dynamic> response = await transport.updateAddress(
        address.type,
        <String, String>{
          ...address.values,
          // The store deliberately disables postcode. Clear an old saved
          // value without ever showing or requiring this field in the app.
          '${prefix}_postcode': '',
        },
      );
      return CustomerAddress(
        type: address.type,
        values: _stringMap(_object(response['address'], 'address')),
      );
    } on CustomerAccountTransportException catch (error, stackTrace) {
      Error.throwWithStackTrace(_transportFailure(error), stackTrace);
    } on FormatException catch (error, stackTrace) {
      Error.throwWithStackTrace(
        CustomerAccountRepositoryException(
          kind: CustomerAccountFailureKind.invalidResponse,
          message: 'The store returned invalid saved address data.',
          cause: error,
        ),
        stackTrace,
      );
    }
  }

  CustomerAccount _account(
    Map<String, dynamic> json,
    Map<String, dynamic>? configuration,
  ) {
    final CustomerProfile profile = _profile(_object(json['profile'], 'profile'));
    final CustomerAddress billing = CustomerAddress(
      type: CustomerAddressType.billing,
      values: _stringMap(_object(json['billing'], 'billing')),
    );
    final CustomerAddress shipping = CustomerAddress(
      type: CustomerAddressType.shipping,
      values: _stringMap(_object(json['shipping'], 'shipping')),
    );
    final Map<String, dynamic> support = _optionalObject(json['support']);
    final String contact = _text(support['contact_url']);
    return CustomerAccount(
      profile: profile,
      billing: billing,
      shipping: shipping,
      support: CustomerSupportDetails(
        email: _text(support['email']),
        phone: _text(support['phone']),
        whatsapp: _text(support['whatsapp']),
        contactUrl: _webUri(contact),
      ),
      addressFields: _addressFields(configuration),
    );
  }

  CustomerProfile _profile(Map<String, dynamic> json) {
    final int id = _integer(json['id']);
    final String email = _text(json['email']);
    if (id <= 0 || email.isEmpty) {
      throw const FormatException('The customer profile is incomplete.');
    }
    return CustomerProfile(
      id: id,
      email: email,
      firstName: _text(json['first_name']),
      lastName: _text(json['last_name']),
      displayName: _text(json['display_name']),
      phone: _text(json['phone']),
      alternatePhone: _text(json['alternate_phone']),
    );
  }

  List<CustomerAddressField> _addressFields(
    Map<String, dynamic>? configuration,
  ) {
    final dynamic rawFields = configuration?['fields'];
    if (rawFields is! List) {
      return _fallbackFields();
    }

    final List<CustomerAddressField> fields = <CustomerAddressField>[];
    final Set<String> seen = <String>{};
    for (final dynamic raw in rawFields) {
      if (raw is! Map) {
        continue;
      }
      final Map<String, dynamic> json = Map<String, dynamic>.from(raw);
      final String key = _text(json['key']);
      final CustomerAddressType? group = switch (_text(json['group'])) {
        'billing' => CustomerAddressType.billing,
        'shipping' => CustomerAddressType.shipping,
        _ => null,
      };
      if (group == null || !_supportedAddressKey(key, group) || !seen.add(key)) {
        continue;
      }
      final bool isPostcode = key.endsWith('_postcode');
      final bool isCountry = key.endsWith('_country');
      fields.add(
        CustomerAddressField(
          key: key,
          addressType: group,
          type: isPostcode || isCountry
              ? CustomerAddressFieldType.hidden
              : _fieldType(_text(json['type'])),
          label: _text(json['label']).isEmpty ? key : _text(json['label']),
          placeholder: _text(json['placeholder']),
          required: isPostcode || isCountry ? false : _boolean(json['required']),
          priority: _integer(json['priority'], fallback: 100),
          options: isPostcode || isCountry
              ? const <String, String>{}
              : _stringMap(json['options']),
          defaultValue: isPostcode
              ? ''
              : isCountry && _text(json['default']).isEmpty
              ? 'EG'
              : _text(json['default']),
          autocomplete: _text(json['autocomplete']),
        ),
      );
    }
    if (fields.isEmpty) {
      return _fallbackFields();
    }
    fields.sort(
      (CustomerAddressField first, CustomerAddressField second) =>
          first.priority.compareTo(second.priority),
    );
    return List<CustomerAddressField>.unmodifiable(fields);
  }

  List<CustomerAddressField> _fallbackFields() {
    final List<CustomerAddressField> fields = <CustomerAddressField>[];
    for (final CustomerAddressType type in CustomerAddressType.values) {
      final String prefix = type == CustomerAddressType.billing
          ? 'billing'
          : 'shipping';
      fields.addAll(<CustomerAddressField>[
        CustomerAddressField(
          key: '${prefix}_first_name',
          type: CustomerAddressFieldType.text,
          addressType: type,
          label: 'الاسم الأول',
          required: true,
          priority: 10,
        ),
        CustomerAddressField(
          key: '${prefix}_last_name',
          type: CustomerAddressFieldType.text,
          addressType: type,
          label: 'اسم العائلة',
          required: true,
          priority: 20,
        ),
        CustomerAddressField(
          key: '${prefix}_address_1',
          type: CustomerAddressFieldType.text,
          addressType: type,
          label: 'العنوان',
          required: true,
          priority: 50,
        ),
        CustomerAddressField(
          key: '${prefix}_city',
          type: CustomerAddressFieldType.text,
          addressType: type,
          label: 'المدينة',
          required: true,
          priority: 70,
        ),
        CustomerAddressField(
          key: '${prefix}_state',
          type: CustomerAddressFieldType.text,
          addressType: type,
          label: 'المحافظة',
          required: true,
          priority: 80,
        ),
        CustomerAddressField(
          key: '${prefix}_country',
          type: CustomerAddressFieldType.hidden,
          addressType: type,
          label: 'الدولة',
          defaultValue: 'EG',
          priority: 90,
        ),
        if (type == CustomerAddressType.billing)
          CustomerAddressField(
            key: 'billing_phone',
            type: CustomerAddressFieldType.telephone,
            addressType: type,
            label: 'رقم الهاتف',
            required: true,
            priority: 100,
          ),
      ]);
    }
    return List<CustomerAddressField>.unmodifiable(fields);
  }

  bool _supportedAddressKey(String key, CustomerAddressType type) {
    final String prefix = type == CustomerAddressType.billing
        ? 'billing_'
        : 'shipping_';
    if (!key.startsWith(prefix)) {
      return false;
    }
    return <String>{
      'first_name',
      'last_name',
      'company',
      'address_1',
      'address_2',
      'city',
      'state',
      'postcode',
      'country',
      'email',
      'phone',
    }.contains(key.substring(prefix.length));
  }

  CustomerAddressFieldType _fieldType(String value) => switch (value) {
    'email' => CustomerAddressFieldType.email,
    'tel' || 'telephone' => CustomerAddressFieldType.telephone,
    'select' || 'country' || 'state' => CustomerAddressFieldType.select,
    'textarea' => CustomerAddressFieldType.textarea,
    'hidden' => CustomerAddressFieldType.hidden,
    _ => CustomerAddressFieldType.text,
  };

  CustomerAccountRepositoryException _transportFailure(
    CustomerAccountTransportException error,
  ) {
    final CustomerAccountFailureKind kind = switch (error.kind) {
      CustomerAccountTransportFailureKind.configuration =>
        CustomerAccountFailureKind.configuration,
      CustomerAccountTransportFailureKind.invalidInput =>
        CustomerAccountFailureKind.invalidInput,
      CustomerAccountTransportFailureKind.unauthorized =>
        CustomerAccountFailureKind.unauthorized,
      CustomerAccountTransportFailureKind.conflict =>
        CustomerAccountFailureKind.conflict,
      CustomerAccountTransportFailureKind.timeout =>
        CustomerAccountFailureKind.timeout,
      CustomerAccountTransportFailureKind.connection =>
        CustomerAccountFailureKind.connection,
      CustomerAccountTransportFailureKind.certificate =>
        CustomerAccountFailureKind.certificate,
      CustomerAccountTransportFailureKind.server =>
        CustomerAccountFailureKind.server,
      CustomerAccountTransportFailureKind.invalidResponse =>
        CustomerAccountFailureKind.invalidResponse,
      CustomerAccountTransportFailureKind.unknown =>
        CustomerAccountFailureKind.unknown,
    };
    return CustomerAccountRepositoryException(
      kind: kind,
      message: error.message,
      statusCode: error.statusCode,
      cause: error,
    );
  }

  Map<String, dynamic> _object(dynamic value, String name) {
    if (value is! Map) {
      throw FormatException('$name must be an object.');
    }
    return Map<String, dynamic>.from(value);
  }

  Map<String, dynamic> _optionalObject(dynamic value) {
    return value is Map
        ? Map<String, dynamic>.from(value)
        : const <String, dynamic>{};
  }

  Map<String, String> _stringMap(dynamic value) {
    if (value is! Map) {
      return const <String, String>{};
    }
    return <String, String>{
      for (final MapEntry<dynamic, dynamic> entry in value.entries)
        if (_text(entry.key).isNotEmpty) _text(entry.key): _text(entry.value),
    };
  }

  String _text(dynamic value) => value?.toString().trim() ?? '';

  Uri? _webUri(String value) {
    if (value.isEmpty) {
      return null;
    }
    final Uri? uri = Uri.tryParse(value);
    return uri != null &&
            uri.hasAuthority &&
            (uri.scheme == 'https' || uri.scheme == 'http')
        ? uri
        : null;
  }

  int _integer(dynamic value, {int fallback = 0}) =>
      value is int ? value : int.tryParse(_text(value)) ?? fallback;

  bool _boolean(dynamic value) {
    if (value is bool) {
      return value;
    }
    return <String>{'1', 'true', 'yes', 'on'}.contains(_text(value).toLowerCase());
  }
}
