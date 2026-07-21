// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final Uri uri = Uri.parse(html.window.location.href);
  final String page = uri.queryParameters['page'] ?? 'catalog';
  final String productId = uri.queryParameters['product'] ?? '1';
  final String initialLocation = switch (page) {
    'home' => '/',
    'category' => '/categories',
    'product' => '/product/$productId',
    'wishlist' => '/wishlist',
    'account' => '/account',
    _ => '/products',
  };
  runApp(
    ProviderScope(
      child: KidiaApp(
        router: createAppRouter(initialLocation: initialLocation),
      ),
    ),
  );
}
