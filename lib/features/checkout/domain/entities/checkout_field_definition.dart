enum CheckoutFieldGroup { billing, shipping, order }

enum CheckoutFieldType {
  text,
  email,
  telephone,
  select,
  textarea,
  checkbox,
  hidden,
}

class CheckoutFieldDefinition {
  CheckoutFieldDefinition({
    required this.key,
    required this.group,
    required this.type,
    required this.label,
    this.placeholder = '',
    this.required = false,
    this.priority = 100,
    Map<String, String> options = const <String, String>{},
    this.defaultValue = '',
    this.autocomplete = '',
  }) : options = Map<String, String>.unmodifiable(options);

  final String key;
  final CheckoutFieldGroup group;
  final CheckoutFieldType type;
  final String label;
  final String placeholder;
  final bool required;
  final int priority;
  final Map<String, String> options;
  final String defaultValue;
  final String autocomplete;

  bool get isVisible => type != CheckoutFieldType.hidden;

  CheckoutFieldDefinition copyWith({
    CheckoutFieldType? type,
    String? label,
    String? placeholder,
    bool? required,
    int? priority,
    Map<String, String>? options,
    String? defaultValue,
    String? autocomplete,
  }) {
    return CheckoutFieldDefinition(
      key: key,
      group: group,
      type: type ?? this.type,
      label: label ?? this.label,
      placeholder: placeholder ?? this.placeholder,
      required: required ?? this.required,
      priority: priority ?? this.priority,
      options: options ?? this.options,
      defaultValue: defaultValue ?? this.defaultValue,
      autocomplete: autocomplete ?? this.autocomplete,
    );
  }
}
