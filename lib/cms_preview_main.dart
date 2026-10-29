import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app/app.dart';
import 'features/auth/data/cms_preview_auth_actions.dart';
import 'features/auth/presentation/auth_screen.dart';
import 'features/auth/presentation/providers/native_auth_providers.dart';
import 'core/localization/app_locale_provider.dart';
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
import 'features/page_builder/presentation/cms_preview_navigation.dart';
import 'features/brands/presentation/providers/brands_providers.dart';
import 'features/splash/presentation/cms_splash_preview.dart';
import 'features/wishlist/data/cms_preview_wishlist_repository.dart';

void main() {
  // The embedded preview must support keyboard and assistive interaction too.
  // Keep semantics enabled for the lifetime of this preview (not the native app).
  WidgetsFlutterBinding.ensureInitialized().ensureSemantics();
  final Uri uri = Uri.parse(web.window.location.href);
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
    'cart' => '/cart',
    _ => '/products',
  };
  final router = createAppRouter(
    initialLocation: initialLocation,
    previewRoutes: [
      GoRoute(
        path: '/cart',
        builder: (_, _) => const CartScreen(checkoutRoute: '/checkout'),
      ),
      // Shopping follows the same signed-out gate as the installed app. The
      // editor's Checkout tab has its own non-ordering design route below.
      GoRoute(path: '/checkout', builder: (_, _) => const AuthScreen()),
      GoRoute(
        path: '/cms-preview/splash',
        builder: (_, _) => const CmsSplashPreview(),
      ),
      GoRoute(
        path: '/cms-preview/checkout',
        builder: (_, _) => const _CmsCheckoutPreview(),
      ),
    ],
  );
  void reportRoute() {
    web.document.documentElement?.setAttribute(
      'data-preview-route',
      router.routeInformationProvider.value.uri.path,
    );
  }

  router.routeInformationProvider.addListener(reportRoute);
  reportRoute();
  // The builder owns one runtime. Only its authenticated same-origin parent
  // can select an editor page; normal mobile taps keep using the native router.
  web.window.addEventListener(
    'message',
    ((web.MessageEvent event) {
      // package:web exposes the raw WindowProxy. Accept only our same-origin
      // parent, retaining the authenticated builder message boundary.
      if (event.source != web.window.parent ||
          event.origin != web.window.location.origin) {
        return;
      }
      dynamic message = event.data.dartify();
      if (message is String) {
        try {
          message = jsonDecode(message);
        } catch (_) {
          return;
        }
      }
      if (message is! Map || message['type'] != 'mobishop-preview-navigate') {
        return;
      }
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
        'cart' => '/cart',
        _ => null,
      };
      if (path != null) navigateCmsPreview(router, path);
    }).toJS,
  );
  runApp(
    ProviderScope(
      overrides: [
        catalogFilterBrandsProvider.overrideWith(
          (ref) => previewCatalog.getFilterBrands(),
        ),
        nativeAuthActionsProvider.overrideWith(
          (ref) => CmsPreviewAuthActions(
            CmsPreviewLayoutBridge.fetchAuthConfiguration,
            isArabic: ref.watch(appLocaleProvider).languageCode == 'ar',
          ),
        ),
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

class _CmsCheckoutPreview extends StatefulWidget {
  const _CmsCheckoutPreview();

  @override
  State<_CmsCheckoutPreview> createState() => _CmsCheckoutPreviewState();
}

class _CmsCheckoutPreviewState extends State<_CmsCheckoutPreview> {
  late Future<Map<String, dynamic>> configuration =
      CmsPreviewLayoutBridge.fetchCheckoutConfiguration();

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
            return FutureBuilder<Map<String, dynamic>>(
              future: configuration,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'تعذر تحميل إعدادات إتمام الطلب من المتجر.',
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              configuration =
                                  CmsPreviewLayoutBridge.fetchCheckoutConfiguration();
                            }),
                            child: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return CheckoutScreen(
                  isPreview: true,
                  key: ValueKey<String>(jsonEncode(layout)),
                  repository: CmsPreviewCheckoutRepository(
                    layout,
                    catalog,
                    configuration: snapshot.data!,
                  ),
                  design: CheckoutDesign.fromApi(layout['checkout_design']),
                );
              },
            );
          },
        );
      },
    );
  }
}
