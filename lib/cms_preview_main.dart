// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/app_router.dart';
import 'features/catalog/data/repositories/cms_preview_catalog_repository.dart';
import 'features/catalog/presentation/providers/catalog_providers.dart';
import 'features/page_builder/presentation/providers/cms_preview_layout_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final Uri uri = Uri.parse(html.window.location.href);
  final String page = uri.queryParameters['page'] ?? 'catalog';
  final String productId = uri.queryParameters['product'] ?? '1';
  final bool usesThemeDemo = uri.queryParameters['demo'] == '1';
  CmsPreviewLayoutBridge.useDemoCatalog = usesThemeDemo;
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
      overrides: [
        if (usesThemeDemo)
          catalogRepositoryProvider.overrideWithValue(
            CmsPreviewCatalogRepository(),
          ),
      ],
      child: KidiaApp(
        router: createAppRouter(initialLocation: initialLocation),
      ),
    ),
  );
}
