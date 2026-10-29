import 'package:flutter/material.dart';

import 'app_ui_control_schema.dart';

/// Only bounded presentation values. Authentication, commerce and navigation
/// decisions are never accepted from this configuration.
class AppUiControls {
  const AppUiControls._(this.values);
  static const defaults = AppUiControls._({});
  final Map<String, dynamic> values;

  factory AppUiControls.fromJson(Object? raw) {
    if (raw is! Map) return defaults;
    final result = <String, dynamic>{};
    for (final entry in appUiControlSchema.entries) {
      final spec = entry.value as Map<String, dynamic>;
      final value = raw[entry.key];
      switch (spec['type']) {
        case 'number':
          if (value is num &&
              value.isFinite &&
              value >= (spec['min'] as num) &&
              value <= (spec['max'] as num)) {
            result[entry.key] = value;
          }
        case 'boolean':
          if (value is bool) result[entry.key] = value;
        case 'choice':
          if (value is String && (spec['options'] as Map).containsKey(value)) {
            result[entry.key] = value;
          }
        case 'color':
          if (value is String && RegExp(r'^#[a-fA-F0-9]{6}$').hasMatch(value)) {
            result[entry.key] = value;
          }
        case 'text':
          if (value is String &&
              value.runes.length <= (spec['max_length'] as int) &&
              !value.contains(RegExp(r'[\x00-\x1f\x7f<>]')) &&
              _validContact(value.trim(), spec['format'])) {
            result[entry.key] = value.trim();
          }
      }
    }
    return AppUiControls._(Map.unmodifiable(result));
  }

  static bool _validContact(String value, Object? format) {
    if (value.isEmpty || format == null) return true;
    return switch (format) {
      'phone' =>
        RegExp(r'^\+?[0-9][0-9 ()-]{5,30}[0-9]$').hasMatch(value) &&
            RegExp(
              r'^[0-9]{7,15}$',
            ).hasMatch(value.replaceAll(RegExp(r'[^0-9]'), '')),
      'email' => RegExp(
        r'^[^\s@<>:/\\?#]+@[^\s@<>:/\\?#]+\.[^\s@<>:/\\?#]+$',
      ).hasMatch(value),
      _ => false,
    };
  }

  dynamic _value(String key) =>
      values[key] ?? appUiControlSchema[key]['default'];
  double number(String key) => (_value(key) as num).toDouble();
  double? optionalNumber(String key) => (values[key] as num?)?.toDouble();
  double numberOr(String key, double fallback) =>
      optionalNumber(key) ?? fallback;
  String choice(String key) => _value(key) as String;
  bool boolean(String key) => _value(key) as bool;
  Color color(String key) => Color(
    0xff000000 | int.parse((_value(key) as String).substring(1), radix: 16),
  );
  String text(String key, bool arabic, String fallback) {
    final value = values['${key}_${arabic ? 'ar' : 'en'}'];
    return value is String && value.isNotEmpty ? value : fallback;
  }
}

class AppUiControlsScope extends InheritedWidget {
  const AppUiControlsScope({
    required this.controls,
    required super.child,
    super.key,
  });
  final AppUiControls controls;
  static AppUiControls of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AppUiControlsScope>()
          ?.controls ??
      AppUiControls.defaults;
  @override
  bool updateShouldNotify(AppUiControlsScope oldWidget) =>
      controls != oldWidget.controls;
}
