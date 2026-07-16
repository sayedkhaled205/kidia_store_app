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
}
