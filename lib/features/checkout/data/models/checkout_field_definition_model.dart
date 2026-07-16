import 'package:kidia_store_app/features/checkout/domain/entities/checkout_field_definition.dart';

abstract final class CheckoutFieldDefinitionModel {
  const CheckoutFieldDefinitionModel._();

  static CheckoutFieldDefinition? tryParse(dynamic value) {
    if (value is! Map) {
      return null;
    }
    final Map<String, dynamic> json = Map<String, dynamic>.from(value);
    final String key = _text(json['key']);
    final CheckoutFieldGroup? group = _group(_text(json['group']));
    if (key.isEmpty || group == null) {
      return null;
    }
    final Map<String, String> options = <String, String>{};
    if (json['options'] is Map) {
      for (final MapEntry<dynamic, dynamic> entry
          in (json['options'] as Map<dynamic, dynamic>).entries) {
        final String optionKey = _text(entry.key);
        if (optionKey.isNotEmpty) {
          options[optionKey] = _text(entry.value);
        }
      }
    }
    return CheckoutFieldDefinition(
      key: key,
      group: group,
      type: _type(_text(json['type'])),
      label: _text(json['label']).isEmpty ? key : _text(json['label']),
      placeholder: _text(json['placeholder']),
      required: _boolean(json['required']),
      priority: _integer(json['priority'], fallback: 100),
      options: options,
      defaultValue: _text(json['default']),
      autocomplete: _text(json['autocomplete']),
    );
  }

  static CheckoutFieldGroup? _group(String value) {
    return switch (value) {
      'billing' => CheckoutFieldGroup.billing,
      'shipping' => CheckoutFieldGroup.shipping,
      'order' => CheckoutFieldGroup.order,
      _ => null,
    };
  }

  static CheckoutFieldType _type(String value) {
    return switch (value) {
      'email' => CheckoutFieldType.email,
      'tel' || 'telephone' => CheckoutFieldType.telephone,
      'select' || 'country' || 'state' => CheckoutFieldType.select,
      'textarea' => CheckoutFieldType.textarea,
      'checkbox' => CheckoutFieldType.checkbox,
      'hidden' => CheckoutFieldType.hidden,
      _ => CheckoutFieldType.text,
    };
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';

  static int _integer(dynamic value, {required int fallback}) {
    return value is int ? value : int.tryParse(_text(value)) ?? fallback;
  }

  static bool _boolean(dynamic value) {
    if (value is bool) {
      return value;
    }
    return <String>{
      '1',
      'true',
      'yes',
      'on',
    }.contains(_text(value).toLowerCase());
  }
}
