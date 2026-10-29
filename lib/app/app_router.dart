import 'package:mobishop_store_app/features/wishlist/application/wishlist_access_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../core/commerce/commerce_connection.dart';
import '../core/commerce/hosted_commerce_destination297.dart';
import 'hosted_commerce_screen297.dart';

import '../features/account/presentation/account_screen.dart';
import '../features/account/presentation/customer_profile_screen.dart';
import '../features/account/presentation/customer_support_screen.dart';
import '../features/account/presentation/saved_addresses_screen.dart';
import '../features/account/presentation/odoo/odoo_account_screen56.dart';
import '../features/account/presentation/odoo/odoo_addresses_screen56.dart';
import '../features/account/presentation/odoo/odoo_orders_screen56.dart';
import '../features/account/presentation/odoo/odoo_profile_screen56.dart';
import '../features/account/presentation/odoo/odoo_support_screen56.dart';
import '../features/auth/domain/entities/auth_session.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/social_auth_callback_screen.dart';
import '../features/brands/presentation/brands_screen.dart';
import '../features/bundles/presentation/bundle_builder_screen.dart';
import '../features/cart/domain/entities/cart_item.dart';
import '../features/cart/presentation/adapters/product_purchase_selection.dart'
    as cart_selection;
import '../features/cart/presentation/cart_screen.dart';
import '../features/cart/presentation/providers/cart_state_providers.dart';
import '../features/catalog/presentation/controllers/catalog_product_list_controller.dart';
import '../features/catalog/presentation/pages/catalog_product_list_screen.dart';
import '../features/catalog/presentation/providers/catalog_providers.dart';
import '../features/categories/presentation/categories_screen.dart';
import '../features/checkout/presentation/checkout_screen.dart';
import '../features/checkout/presentation/odoo_checkout_screen101.dart';
import '../features/checkout/presentation/checkout_presentation_provider.dart';
import '../features/checkout/presentation/providers/checkout_customer_binding_provider.dart';
import '../features/checkout/domain/entities/checkout_presentation.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/orders/presentation/customer_orders_screen.dart';
import '../features/page_builder/domain/cms_page_layout.dart';
import '../features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import '../features/product/presentation/product_detail_screen.dart';
import '../features/product/application/product_detail_controller.dart'
    as product_selection;
import '../features/search/presentation/search_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/splash/presentation/splash_providers.dart';
import '../features/splash/domain/splash_config.dart';
import '../features/wishlist/application/wishlist_repository_provider.dart';
export '../features/wishlist/application/wishlist_repository_provider.dart';
import '../features/wishlist/domain/repositories/wishlist_repository.dart';
import '../features/wishlist/presentation/wishlist_screen.dart';
import 'app_startup_provider.dart';
import 'commerce_route_destination.dart';
import 'main_shell.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  final GoRouter router = createAppRouter();

  ref.onDispose(router.dispose);

  return router;
});

GoRouter createAppRouter({
  String initialLocation = '/',
  List<RouteBase> previewRoutes = const [],
}) {
  // Odoo's session cookie and customer entities never enter the Woo bearer
  // graph. CMS preview keeps its existing rendering/identity contract.
  final bool useOdooCustomer =
      !AppConfig.isCmsPreview &&
      AppConfig.commercePlatform == CommercePlatform.odoo;
  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      if (AppConfig.isCmsPreview ||
          AppConfig.commercePlatform == CommercePlatform.wooCommerce) {
        return null;
      }
      if (AppConfig.commercePlatform == CommercePlatform.shopify &&
          state.uri.path == '/checkout') {
        return '/cart';
      }
      final destination = HostedCommerceDestination297.forRoute(
        AppConfig.commerceConnection,
        state.uri.path,
      );
      return destination == null
          ? null
          : Uri(
              path: '/store-flow',
              queryParameters: {'route': state.uri.path},
            ).toString();
    },
    errorBuilder: (context, state) {
      return CommerceRouteDestination(
        icon: Icons.wrong_location_outlined,
        title: 'الصفحة غير موجودة',
        description: 'تعذر فتح المسار المطلوب.',
        onGoHome: () => context.go('/'),
      );
    },
    routes: [
      ...previewRoutes,
      GoRoute(
        path: '/store-flow',
        builder: (context, state) {
          final route = state.uri.queryParameters['route'] ?? '';
          final destination = HostedCommerceDestination297.forRoute(
            AppConfig.commerceConnection,
            route,
          );
          if (destination == null) {
            return const CommerceRouteDestination(
              icon: Icons.link_off,
              title: 'الصفحة غير متاحة',
              description: 'تعذر فتح هذا الرابط.',
            );
          }
          return HostedCommerceScreen297(
            destination: destination,
            route: route,
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _AppStartupGate(
            child: MainShell(navigationShell: navigationShell),
          );
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const _PageAvailabilityGate(
                  page: 'home',
                  child: HomePage(),
                ),
                routes: [
                  // Keep search and its product destination on the same shell
                  // stack so opening a result does not duplicate its Page key.
                  GoRoute(
                    path: 'search',
                    builder: (context, state) => SearchScreen(
                      initialQuery: state.uri.queryParameters['q'] ?? '',
                    ),
                  ),
                  GoRoute(
                    path: 'bundle/:bundleId',
                    builder: (context, state) {
                      final String bundleId =
                          state.pathParameters['bundleId'] ?? '';
                      return BundleBuilderScreen(bundleId: bundleId);
                    },
                  ),
                  GoRoute(
                    path: 'product/:productId',
                    builder: (context, state) {
                      final String productId =
                          state.pathParameters['productId'] ?? '';
                      final int? parsedProductId = _positiveId(productId);

                      if (parsedProductId == null) {
                        return const CommerceRouteDestination(
                          icon: Icons.shopping_bag_outlined,
                          title: 'تفاصيل المنتج',
                          description: 'لم يتم تحديد منتج صالح.',
                        );
                      }

                      return _PageAvailabilityGate(
                        page: 'product',
                        child: Consumer(
                          builder: (context, ref, child) {
                            final addToCart = ref.read(
                              addProductPurchaseSelectionProvider,
                            );
                            return ProductDetailScreen(
                              productId: parsedProductId,
                              repository: ref.watch(catalogRepositoryProvider),
                              onAddToCart:
                                  (
                                    product_selection.ProductPurchaseSelection
                                    selection,
                                  ) async {
                                    final result = await addToCart(
                                      cart_selection.ProductPurchaseSelection(
                                        productId:
                                            selection.variationId ??
                                            selection.productId,
                                        quantity: selection.quantity,
                                        catalogProductId: selection.productId,
                                        variantId: selection.variationId,
                                        variation: selection
                                            .selectedAttributes
                                            .entries
                                            .map(
                                              (entry) => CartItemVariation(
                                                attribute: entry.key,
                                                value: entry.value,
                                              ),
                                            )
                                            .toList(growable: false),
                                      ),
                                    );
                                    if (!result.succeeded) {
                                      throw StateError(
                                        result.message ??
                                            'تعذر إضافة المنتج إلى السلة.',
                                      );
                                    }
                                  },
                              isWishlisted: (int productId) async {
                                final repository = ref.read(
                                  wishlistRepositoryProvider,
                                );
                                final ids = await repository.loadProductIds();
                                return ids.contains(productId);
                              },
                              onWishlistToggle: (product) async {
                                final access = ref.read(wishlistAccessProvider);
                                if (access.loading) return false;
                                if (access.requiresSignIn && !access.signedIn) {
                                  await context.push('/auth');
                                  return false;
                                }
                                final repository = ref.read(
                                  wishlistRepositoryProvider,
                                );
                                var saved = false;
                                await repository.updateProductIds((ids) {
                                  saved = !ids.contains(product.id);
                                  return saved
                                      ? <int>[product.id, ...ids]
                                      : ids
                                            .where((id) => id != product.id)
                                            .toList();
                                });
                                return saved;
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'collection/:collectionId',
                    builder: (context, state) {
                      final String collectionId =
                          state.pathParameters['collectionId'] ?? '';

                      if (collectionId.isEmpty) {
                        return const CommerceRouteDestination(
                          icon: Icons.collections_bookmark_outlined,
                          title: 'مجموعة المنتجات',
                          description: 'لم يتم تحديد المجموعة المطلوبة.',
                        );
                      }

                      return _PageAvailabilityGate(
                        page: 'catalog',
                        child: CatalogProductListScreen(
                          request: CatalogProductListRequest(
                            title: collectionId,
                            collection: collectionId,
                          ),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'brand/:brandId',
                    builder: (context, state) {
                      final String brandId =
                          state.pathParameters['brandId'] ?? '';
                      final int? parsedBrandId = _positiveId(brandId);

                      if (parsedBrandId == null) {
                        return const CommerceRouteDestination(
                          icon: Icons.sell_outlined,
                          title: 'منتجات العلامة التجارية',
                          description: 'لم يتم تحديد علامة تجارية صالحة.',
                        );
                      }

                      return _PageAvailabilityGate(
                        page: 'catalog',
                        child: CatalogProductListScreen(
                          request: CatalogProductListRequest(
                            brandId: parsedBrandId,
                          ),
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'brands',
                    builder: (context, state) {
                      return BrandsScreen(
                        onBrandTap: (brand) =>
                            context.push('/brand/${brand.id}'),
                      );
                    },
                  ),
                  // Backwards-compatible destination for previously saved
                  // CMS actions that used /products query parameters.
                  GoRoute(
                    path: 'products',
                    builder: (context, state) {
                      final String? collection =
                          state.uri.queryParameters['collection'];
                      final String? brand = state.uri.queryParameters['brand'];

                      if (collection != null && collection.isNotEmpty) {
                        return _PageAvailabilityGate(
                          page: 'catalog',
                          child: CatalogProductListScreen(
                            request: CatalogProductListRequest(
                              title: collection,
                              collection: collection,
                            ),
                          ),
                        );
                      }

                      if (brand != null && brand.isNotEmpty) {
                        final int? parsedBrandId = _positiveId(brand);

                        if (parsedBrandId != null) {
                          return _PageAvailabilityGate(
                            page: 'catalog',
                            child: CatalogProductListScreen(
                              request: CatalogProductListRequest(
                                brandId: parsedBrandId,
                              ),
                            ),
                          );
                        }
                      }

                      return const _PageAvailabilityGate(
                        page: 'catalog',
                        child: CatalogProductListScreen(
                          request: CatalogProductListRequest(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/categories',
                builder: (context, state) => const _PageAvailabilityGate(
                  page: 'category',
                  child: CategoriesScreen(),
                ),
                routes: [
                  GoRoute(
                    path: ':categoryId',
                    builder: (context, state) {
                      final String categoryId =
                          state.pathParameters['categoryId'] ?? '';
                      final int? parsedCategoryId = _positiveId(categoryId);

                      if (parsedCategoryId == null) {
                        return const CommerceRouteDestination(
                          icon: Icons.category_outlined,
                          title: 'منتجات القسم',
                          description: 'لم يتم تحديد قسم صالح.',
                        );
                      }

                      return _PageAvailabilityGate(
                        page: 'catalog',
                        child: CatalogProductListScreen(
                          request: CatalogProductListRequest(
                            categoryId: parsedCategoryId,
                            title: state.uri.queryParameters['name'] ?? '',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/wishlist',
                builder: (context, state) => _PageAvailabilityGate(
                  page: 'wishlist',
                  child: Consumer(
                    builder: (context, ref, child) {
                      final access = ref.watch(wishlistAccessProvider);
                      if (!AppConfig.isCmsPreview && access.loading) {
                        return const _ProtectedAccountLoading();
                      }
                      return WishlistScreen(
                        repository: ref.watch(wishlistRepositoryProvider),
                        catalogRepository: ref.watch(catalogRepositoryProvider),
                        signedIn: access.signedIn,
                        requiresSignIn: access.requiresSignIn,
                        onProductTap: (product) =>
                            context.push('/product/${product.id}'),
                        onContinueShopping: () => context.go('/'),
                        onSignIn: () => context.push('/auth'),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => _PageAvailabilityGate(
                  page: 'account',
                  child: useOdooCustomer
                      ? const OdooAccountScreen56()
                      : const AccountScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) =>
            useOdooCustomer ? const OdooSignInScreen56() : const AuthScreen(),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) {
            if (useOdooCustomer) {
              return const OdooCustomerGate56(child: OdooOrdersScreen56());
            }
            final AsyncValue<AuthSession?> authState = ref.watch(
              authControllerProvider,
            );
            if (authState.isLoading) {
              return const _ProtectedAccountLoading();
            }
            if (authState.asData?.value == null) {
              return const AuthScreen(popOnSuccess: false);
            }
            return const CustomerOrdersScreen();
          },
        ),
      ),
      GoRoute(
        path: '/orders/:orderId',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) {
            final id = _positiveId(state.pathParameters['orderId'] ?? '');
            if (id == null) {
              return const CommerceRouteDestination(
                icon: Icons.receipt_long_outlined,
                title: 'تفاصيل الطلب',
                description: 'لم يتم تحديد طلب صحيح.',
              );
            }
            if (useOdooCustomer) {
              return OdooCustomerGate56(
                child: OdooOrderDetailsScreen56(orderId: id),
              );
            }
            final authState = ref.watch(authControllerProvider);
            if (authState.isLoading) return const _ProtectedAccountLoading();
            if (authState.asData?.value == null) {
              return const AuthScreen(popOnSuccess: false);
            }
            return CustomerOrdersScreen(key: ValueKey(id), initialOrderId: id);
          },
        ),
      ),
      GoRoute(
        path: '/addresses',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) {
            if (useOdooCustomer) {
              return const OdooCustomerGate56(child: OdooAddressesScreen56());
            }
            final AsyncValue<AuthSession?> authState = ref.watch(
              authControllerProvider,
            );
            if (authState.isLoading) {
              return const _ProtectedAccountLoading();
            }
            if (authState.asData?.value == null) {
              return const AuthScreen(popOnSuccess: false);
            }
            return const SavedAddressesScreen();
          },
        ),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) {
            if (useOdooCustomer) {
              return const OdooCustomerGate56(child: OdooProfileScreen56());
            }
            final AsyncValue<AuthSession?> authState = ref.watch(
              authControllerProvider,
            );
            if (authState.isLoading) {
              return const _ProtectedAccountLoading();
            }
            if (authState.asData?.value == null) {
              return const AuthScreen(popOnSuccess: false);
            }
            return const CustomerProfileScreen();
          },
        ),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) {
            if (useOdooCustomer) {
              return const OdooCustomerGate56(child: OdooSupportScreen56());
            }
            final AsyncValue<AuthSession?> authState = ref.watch(
              authControllerProvider,
            );
            if (authState.isLoading) {
              return const _ProtectedAccountLoading();
            }
            if (authState.asData?.value == null) {
              return const AuthScreen(popOnSuccess: false);
            }
            return const CustomerSupportScreen();
          },
        ),
      ),
      GoRoute(
        path: '/social-callback',
        builder: (context, state) => SocialAuthCallbackScreen(
          code: state.uri.queryParameters['code'] ?? '',
          state: state.uri.queryParameters['state'] ?? '',
        ),
      ),
      GoRoute(
        path: '/cart',
        builder: (context, state) =>
            const CartScreen(checkoutRoute: '/checkout'),
      ),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) {
            if (useOdooCustomer) return const OdooCheckoutScreen101();
            final AsyncValue<AuthSession?> authState = ref.watch(
              authControllerProvider,
            );
            final AuthSession? session = authState.value;
            if (authState.isLoading && session == null) {
              return const _CheckoutAuthLoading();
            }
            if (authState.hasError || session == null || session.isExpired) {
              return const AuthScreen(popOnSuccess: false);
            }
            final binding = ref.watch(checkoutCustomerBindingProvider);
            if (binding == null) {
              return const AuthScreen(popOnSuccess: false);
            }
            return CheckoutScreen(
              key: ObjectKey(binding),
              repository: binding.repository,
              customerEmail: binding.initialEmail,
              onBackToCart: () => context.go('/cart'),
              onReviewOrders: () => context.push('/orders'),
              onOrderSuccess: (_) => ref.invalidate(cartControllerProvider),
              onContinueShopping: () => context.go('/'),
              onViewOrderDetails: (id) => context.push('/orders/$id'),
              design:
                  ref.watch(checkoutPresentationProvider).value?.design ??
                  CheckoutDesign.classic,
            );
          },
        ),
      ),
    ],
  );
}

class _CheckoutAuthLoading extends StatelessWidget {
  const _CheckoutAuthLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(key: Key('checkout-auth-loading')),
      ),
    );
  }
}

class _ProtectedAccountLoading extends StatelessWidget {
  const _ProtectedAccountLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(key: Key('account-auth-loading')),
      ),
    );
  }
}

class _PageAvailabilityGate extends ConsumerWidget {
  const _PageAvailabilityGate({required this.page, required this.child});

  final String page;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CmsPageLayout> state = ref.watch(
      cmsPageLayoutProvider(page),
    );
    if (state.value == null && !state.hasError) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            key: Key('page-availability-loading'),
          ),
        ),
      );
    }
    final CmsPageLayout layout = state.value ?? CmsPageLayout.fallback(page);
    if (!AppConfig.isCmsPreview && !layout.enabled) {
      return const CommerceRouteDestination(
        icon: Icons.visibility_off_outlined,
        title: 'الصفحة غير متاحة',
        description: 'تم إيقاف هذه الصفحة من إعدادات التطبيق.',
      );
    }
    return child;
  }
}

int? _positiveId(String value) {
  final int? id = int.tryParse(value.trim());
  return id != null && id > 0 ? id : null;
}

class _AppStartupGate extends ConsumerWidget {
  const _AppStartupGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<void> startupState = ref.watch(appStartupProvider);

    return startupState.when(
      loading: () => SplashScreen(
        config: ref.watch(splashConfigProvider).value ?? const SplashConfig(),
      ),
      error: (error, stackTrace) => _StartupErrorScreen(
        error: error,
        onRetry: () => ref.invalidate(appStartupProvider),
      ),
      data: (_) => child,
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  const _StartupErrorScreen({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 16),
              const Text(
                'تعذر تشغيل التطبيق',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onRetry,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
