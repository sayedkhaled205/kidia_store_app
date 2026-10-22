import 'package:flutter/material.dart';

class SplashConfig {
  const SplashConfig({
    this.enabled = true,
    this.imageUrl = '',
    this.backgroundColor = Colors.white,
    this.backgroundColorEnd = Colors.white,
    this.duration = const Duration(seconds: 2),
    this.imageWidth = 140,
    this.imageHeight = 140,
    this.imageFit = BoxFit.contain,
    this.imageAspectRatio = 0,
    this.imageShape = 'none',
    this.showStoreName = true,
    this.storeName = '',
    this.textColor = const Color(0xFF253A46),
    this.showLoader = true,
    this.loaderColor = const Color(0xFF4EA999),
  });

  final bool enabled;
  final String imageUrl;
  final Color backgroundColor;
  final Color backgroundColorEnd;
  final Duration duration;
  final double imageWidth;
  final double imageHeight;
  final BoxFit imageFit;
  final double imageAspectRatio;
  final String imageShape;
  final bool showStoreName;
  final String storeName;
  final Color textColor;
  final bool showLoader;
  final Color loaderColor;

  factory SplashConfig.fromJson(Map<String, dynamic> json) => SplashConfig(
    enabled: _bool(json['enabled'], true),
    imageUrl: '${json['image_url'] ?? ''}'.trim(),
    backgroundColor: _color(json['background_color'], Colors.white),
    backgroundColorEnd: _color(json['background_color_end'], Colors.white),
    duration: Duration(
      milliseconds: _number(
        json['duration_ms'],
        2000,
      ).clamp(500, 10000).round(),
    ),
    imageWidth: _number(json['image_width'], 140).clamp(40, 320),
    imageHeight: _number(json['image_height'], 140).clamp(40, 320),
    imageAspectRatio: _number(json['image_aspect_ratio'], 0).clamp(0, 10),
    imageFit: switch ('${json['image_fit']}') {
      'cover' => BoxFit.cover,
      'fill' => BoxFit.fill,
      _ => BoxFit.contain,
    },
    imageShape: '${json['image_shape'] ?? 'none'}',
    showStoreName: _bool(json['show_store_name'], true),
    storeName: '${json['store_name'] ?? ''}'.trim(),
    textColor: _color(json['text_color'], const Color(0xFF253A46)),
    showLoader: _bool(json['show_loader'], true),
    loaderColor: _color(json['loader_color'], const Color(0xFF4EA999)),
  );
}

bool _bool(dynamic value, bool fallback) => value is bool
    ? value
    : value is num
    ? value != 0
    : value is String
    ? <String>{'1', 'true', 'yes', 'on'}.contains(value.toLowerCase())
    : fallback;
double _number(dynamic value, double fallback) =>
    value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
Color _color(dynamic value, Color fallback) {
  final hex = '$value'.replaceFirst('#', '');
  return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)
      ? Color(int.parse('FF$hex', radix: 16))
      : fallback;
}
