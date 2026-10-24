import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_field_definition.dart';
import 'checkout_country_data.dart';

/// Shared address rules for the real checkout and its non-ordering preview.
abstract final class CheckoutFieldNormalizer {
  static List<CheckoutFieldDefinition> normalize(
    List<CheckoutFieldDefinition> fields,
    Map<String, dynamic> configuration,
  ) {
    final Map<String, dynamic>? defaults = configuration['defaults'] is Map
        ? Map<String, dynamic>.from(configuration['defaults'] as Map)
        : null;
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
      country = '';
    }

    Map<String, String> states = _stringMap(defaults?['states']);
    if (states.isEmpty) {
      states = CheckoutCountryData.statesFor(country);
    }

    final List<CheckoutFieldDefinition> normalized =
        <CheckoutFieldDefinition>[];
    final Set<String> seenKeys = <String>{};
    for (final CheckoutFieldDefinition field in fields) {
      if (!seenKeys.add(field.key)) {
        continue;
      }
      if (_isCountryField(field.key)) {
        normalized.add(
          field.copyWith(
            defaultValue: field.defaultValue.isEmpty
                ? country
                : field.defaultValue,
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
            required: field.required,
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
        configuration['renderer'] == 'native' && configuration['version'] == 8
        ? <CheckoutFieldDefinition>[]
        : List<CheckoutFieldDefinition>.of(normalized);
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
          optionsByCountry: field.optionsByCountry,
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

  static String? _billingCounterpartFor(CheckoutFieldDefinition field) {
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

  static Map<String, String> _stringMap(dynamic raw) {
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

  static bool _isCountryField(String key) =>
      key == 'billing_country' || key == 'shipping_country';

  static bool _isStateField(String key) =>
      key == 'billing_state' || key == 'shipping_state';
}
