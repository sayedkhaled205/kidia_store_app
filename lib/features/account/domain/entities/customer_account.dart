enum CustomerAddressType { billing, shipping }

enum CustomerAddressFieldType {
  text,
  email,
  telephone,
  select,
  textarea,
  hidden,
}

class CustomerProfile {
  const CustomerProfile({
    required this.id,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.displayName = '',
  });

  final int id;
  final String email;
  final String firstName;
  final String lastName;
  final String displayName;
}

class CustomerAddress {
  CustomerAddress({
    required this.type,
    Map<String, String> values = const <String, String>{},
  }) : values = Map<String, String>.unmodifiable(values);

  final CustomerAddressType type;
  final Map<String, String> values;

  bool get isEmpty => values.entries
      .where(
        (MapEntry<String, String> entry) =>
            !entry.key.endsWith('_country') &&
            !entry.key.endsWith('_email') &&
            !entry.key.endsWith('_phone'),
      )
      .every((MapEntry<String, String> entry) => entry.value.trim().isEmpty);

  String valueFor(String key) => values[key]?.trim() ?? '';
}

class CustomerAddressField {
  CustomerAddressField({
    required this.key,
    required this.type,
    required this.addressType,
    required this.label,
    this.placeholder = '',
    this.required = false,
    this.priority = 100,
    Map<String, String> options = const <String, String>{},
    this.defaultValue = '',
    this.autocomplete = '',
  }) : options = Map<String, String>.unmodifiable(options);

  final String key;
  final CustomerAddressFieldType type;
  final CustomerAddressType addressType;
  final String label;
  final String placeholder;
  final bool required;
  final int priority;
  final Map<String, String> options;
  final String defaultValue;
  final String autocomplete;

  bool get isVisible => type != CustomerAddressFieldType.hidden;
}

class CustomerSupportDetails {
  const CustomerSupportDetails({
    this.email = '',
    this.phone = '',
    this.whatsapp = '',
    this.contactUrl,
  });

  final String email;
  final String phone;
  final String whatsapp;
  final Uri? contactUrl;
}

class CustomerAccount {
  CustomerAccount({
    required this.profile,
    required this.billing,
    required this.shipping,
    required this.support,
    List<CustomerAddressField> addressFields =
        const <CustomerAddressField>[],
  }) : addressFields = List<CustomerAddressField>.unmodifiable(addressFields);

  final CustomerProfile profile;
  final CustomerAddress billing;
  final CustomerAddress shipping;
  final CustomerSupportDetails support;
  final List<CustomerAddressField> addressFields;

  CustomerAddress address(CustomerAddressType type) =>
      type == CustomerAddressType.billing ? billing : shipping;

  List<CustomerAddressField> fieldsFor(CustomerAddressType type) =>
      addressFields
          .where((CustomerAddressField field) => field.addressType == type)
          .toList(growable: false);
}
