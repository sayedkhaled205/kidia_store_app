import 'package:flutter/material.dart';

class SplashConfig {
  const SplashConfig({
    this.enabled = true,
    this.imageUrl = '',
    this.backgroundColor = const Color(0xFF2F806E),
    this.backgroundColorEnd = const Color(0xFF236B59),
    this.duration = const Duration(seconds: 2),
    this.imageWidth = 140,
    this.imageHeight = 140,
    this.imageFit = BoxFit.contain,
    this.imageShape = 'none',
    this.showStoreName = true,
    this.storeName = '',
    this.textColor = Colors.white,
    this.showLoader = true,
    this.loaderColor = Colors.white,
  });

  final bool enabled;
  final String imageUrl;
  final Color backgroundColor;
  final Color backgroundColorEnd;
  final Duration duration;
  final double imageWidth;
  final double imageHeight;
  final BoxFit imageFit;
  final String imageShape;
  final bool showStoreName;
  final String storeName;
  final Color textColor;
  final bool showLoader;
  final Color loaderColor;

  factory SplashConfig.fromJson(Map<String, dynamic> json) => SplashConfig(
    enabled: _bool(json['enabled'], true),
    imageUrl: '${json['image_url'] ?? ''}'.trim(),
    backgroundColor: _color(json['background_color'], const Color(0xFF2F806E)),
    backgroundColorEnd: _color(json['background_color_end'], const Color(0xFF236B59)),
    duration: Duration(milliseconds: _number(json['duration_ms'], 2000).clamp(500, 10000).round()),
    imageWidth: _number(json['image_width'], 140).clamp(40, 320),
    imageHeight: _number(json['image_height'], 140).clamp(40, 320),
    imageFit: switch ('${json['image_fit']}') { 'cover' => BoxFit.cover, 'fill' => BoxFit.fill, _ => BoxFit.contain },
    imageShape: '${json['image_shape'] ?? 'none'}',
    showStoreName: _bool(json['show_store_name'], true),
    storeName: '${json['store_name'] ?? ''}'.trim(),
    textColor: _color(json['text_color'], Colors.white),
    showLoader: _bool(json['show_loader'], true),
    loaderColor: _color(json['loader_color'], Colors.white),
  );
}

bool _bool(dynamic value, bool fallback) => value is bool ? value : value is num ? value != 0 : value is String ? <String>{'1','true','yes','on'}.contains(value.toLowerCase()) : fallback;
double _number(dynamic value, double fallback) => value is num ? value.toDouble() : double.tryParse('$value') ?? fallback;
Color _color(dynamic value, Color fallback) { final hex='$value'.replaceFirst('#',''); return RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex) ? Color(int.parse('FF$hex',radix:16)) : fallback; }
