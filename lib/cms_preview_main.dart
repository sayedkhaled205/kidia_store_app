// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/app.dart';
import 'features/cart/data/repositories/cms_preview_cart_repository.dart';
import 'features/cart/presentation/providers/cart_providers.dart';
import 'features/cart/presentation/cart_screen.dart';
import 'app/app_router.dart';
import 'features/catalog/data/repositories/cms_preview_catalog_repository.dart';
import 'features/catalog/presentation/providers/catalog_providers.dart';
import 'features/checkout/data/repositories/cms_preview_checkout_repository.dart';
import 'features/checkout/domain/entities/checkout_presentation.dart';
import 'features/checkout/presentation/checkout_screen.dart';
import 'features/page_builder/presentation/providers/cms_preview_layout_bridge.dart';
import 'features/splash/presentation/cms_splash_preview.dart';
import 'features/wishlist/data/cms_preview_wishlist_repository.dart';

void main() {
  // The embedded preview must support keyboard and assistive interaction too.
  // Keep semantics enabled for the lifetime of this preview (not the native app).
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  final Uri uri = Uri.parse(html.window.location.href);
  final String page = uri.queryParameters['page'] ?? 'catalog';
  final String productId = uri.queryParameters['product'] ?? '1';
  final bool usesThemeDemo = uri.queryParameters['demo'] == '1';
  CmsPreviewLayoutBridge.useDemoCatalog = usesThemeDemo;
  CmsPreviewLayoutBridge.useLiveCatalog = !usesThemeDemo;
  final previewCatalog = CmsPreviewCatalogRepository();
  final String initialLocation = switch (page) {
    'home' => '/',
    'category' => '/categories',
    'product' => '/product/$productId',
    'wishlist' => '/wishlist',
    'account' => '/account',
    'splash' => '/cms-preview/splash',
    'checkout' => '/cms-preview/checkout',
    _ => '/products',
  };
  final router = createAppRouter(
    initialLocation: initialLocation,
    previewRoutes: [
      GoRoute(
        path: '/cart',
        builder: (_, __) =>
            const CartScreen(checkoutRoute: '/cms-preview/checkout'),
      ),
      GoRoute(path: '/checkout', redirect: (_, __) => '/cms-preview/checkout'),
      GoRoute(
        path: '/cms-preview/splash',
        builder: (_, __) => const CmsSplashPreview(),
      ),
      GoRoute(
        path: '/cms-preview/checkout',
        builder: (_, __) => const _CmsCheckoutPreview(),
      ),
    ],
  );
  void reportRoute() {
    html.document.documentElement?.dataset['previewRoute'] =
        router.routeInformationProvider.value.uri.path;
  }

  router.routeInformationProvider.addListener(reportRoute);
  reportRoute();
  // The builder owns one runtime. Only its authenticated same-origin parent
  // can select an editor page; normal mobile taps keep using the native router.
  html.window.onMessage.listen((event) {
    // dart:html wraps a foreign Window and MessageEvent.source can become
    // null during that conversion. Compare the raw JS WindowProxy identities
    // instead, retaining both the parent-only and same-origin boundaries.
    if (!identical(
          js.getProperty<Object?>(event, 'source'),
          js.getProperty<Object?>(html.window, 'parent'),
        ) ||
        event.origin != html.window.location.origin)
      return;
    dynamic message = event.data;
    if (message is String) {
      try {
        message = jsonDecode(message);
      } catch (_) {
        return;
      }
    }
    if (message is! Map || message['type'] != 'mobishop-preview-navigate')
      return;
    final id = int.tryParse('${message['product'] ?? ''}');
    final path = switch (message['page']) {
      'home' => '/',
      'category' => '/categories',
      'catalog' => '/products',
      'product' => id != null && id > 0 ? '/product/$id' : '/products',
      'wishlist' => '/wishlist',
      'account' => '/account',
      'splash' => '/cms-preview/splash',
      'checkout' => '/cms-preview/checkout',
      _ => null,
    };
    if (path != null) router.go(path);
  });
  runApp(
    ProviderScope(
      overrides: [
        catalogRepositoryProvider.overrideWithValue(previewCatalog),
        cartRepositoryProvider.overrideWithValue(
          CmsPreviewCartRepository(previewCatalog),
        ),
        wishlistRepositoryProvider.overrideWithValue(
          CmsPreviewWishlistRepository(previewCatalog),
        ),
      ],
      child: MobiShopApp(router: router),
    ),
  );
}

class _CmsCheckoutPreview extends StatelessWidget {
  const _CmsCheckoutPreview();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: CmsPreviewLayoutBridge.layoutsFor('checkout'),
      builder: (context, layoutSnapshot) {
        final Map<String, dynamic>? layout = layoutSnapshot.data;
        if (layout == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return FutureBuilder<Map<String, dynamic>>(
          future: CmsPreviewLayoutBridge.demoCatalog,
          builder: (context, catalogSnapshot) {
            final Map<String, dynamic>? catalog = catalogSnapshot.data;
            if (catalog == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return CheckoutScreen(
              isPreview: true,
              key: ValueKey<String>(jsonEncode(layout)),
              repository: CmsPreviewCheckoutRepository(layout, catalog),
              design: CheckoutDesign.fromApi(layout['checkout_design']),
            );
          },
        );
      },
    );
  }
}
