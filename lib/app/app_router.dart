import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/account/presentation/account_screen.dart';
import '../features/account/presentation/customer_profile_screen.dart';
import '../features/account/presentation/customer_support_screen.dart';
import '../features/account/presentation/saved_addresses_screen.dart';
import '../features/auth/domain/entities/auth_session.dart';
import '../features/auth/presentation/auth_screen.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/social_auth_callback_screen.dart';
import '../features/brands/presentation/brands_screen.dart';
import '../features/cart/data/network/cart_token_store.dart';
import '../features/cart/domain/entities/cart_item.dart';
import '../features/cart/presentation/adapters/product_purchase_selection.dart'
    as cart_selection;
import '../features/cart/presentation/cart_screen.dart';
import '../features/cart/presentation/providers/cart_providers.dart';
import '../features/cart/presentation/providers/cart_state_providers.dart';
import '../features/catalog/presentation/controllers/catalog_product_list_controller.dart';
import '../features/catalog/presentation/pages/catalog_product_list_screen.dart';
import '../features/catalog/presentation/providers/catalog_providers.dart';
import '../features/categories/presentation/categories_screen.dart';
import '../features/checkout/data/network/checkout_api_transport.dart';
import '../features/checkout/data/repositories/store_api_checkout_repository.dart';
import '../features/checkout/presentation/checkout_screen.dart';
import '../features/checkout/presentation/checkout_suggestions_provider.dart';
import '../features/checkout/domain/entities/checkout_suggestions.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/orders/presentation/customer_orders_screen.dart';
import '../features/product/presentation/product_detail_screen.dart';
import '../features/product/application/product_detail_controller.dart'
    as product_selection;
import '../features/search/presentation/search_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/splash/presentation/splash_providers.dart';
import '../features/splash/domain/splash_config.dart';
import '../features/wishlist/data/shared_preferences_wishlist_repository.dart';
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

final Provider<WishlistRepository> wishlistRepositoryProvider =
    Provider<WishlistRepository>((ref) {
      return SharedPreferencesWishlistRepository.forConfiguredStore();
    });

GoRouter createAppRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    errorBuilder: (context, state) {
      return CommerceRouteDestination(
        icon: Icons.wrong_location_outlined,
        title: 'الصفحة غير موجودة',
        description: 'تعذر فتح المسار المطلوب.',
        onGoHome: () => context.go('/'),
      );
    },
    routes: [
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
                builder: (context, state) => const HomePage(),
                routes: [
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

                      return Consumer(
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
                              final repository = ref.read(
                                wishlistRepositoryProvider,
                              );
                              final List<int> ids = await repository
                                  .loadProductIds();
                              final bool isSaved = ids.contains(product.id);
                              final List<int> nextIds = isSaved
                                  ? ids
                                        .where((int id) => id != product.id)
                                        .toList(growable: false)
                                  : <int>[...ids, product.id];
                              await repository.saveProductIds(nextIds);
                              return !isSaved;
                            },
                          );
                        },
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

                      return CatalogProductListScreen(
                        request: CatalogProductListRequest(
                          title: collectionId,
                          collection: collectionId,
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

                      return CatalogProductListScreen(
                        request: CatalogProductListRequest(
                          brandId: parsedBrandId,
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
                        return CatalogProductListScreen(
                          request: CatalogProductListRequest(
                            title: collection,
                            collection: collection,
                          ),
                        );
                      }

                      if (brand != null && brand.isNotEmpty) {
                        final int? parsedBrandId = _positiveId(brand);

                        if (parsedBrandId != null) {
                          return CatalogProductListScreen(
                            request: CatalogProductListRequest(
                              brandId: parsedBrandId,
                            ),
                          );
                        }
                      }

                      return const CatalogProductListScreen(
                        request: CatalogProductListRequest(),
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
                builder: (context, state) => const CategoriesScreen(),
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

                      return CatalogProductListScreen(
                        request: CatalogProductListRequest(
                          categoryId: parsedCategoryId,
                          title: state.uri.queryParameters['name'] ?? '',
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
                builder: (context, state) => Consumer(
                  builder: (context, ref, child) => WishlistScreen(
                    repository: ref.watch(wishlistRepositoryProvider),
                    catalogRepository: ref.watch(catalogRepositoryProvider),
                    onProductTap: (product) =>
                        context.push('/product/${product.id}'),
                    onContinueShopping: () => context.go('/'),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/account',
                builder: (context, state) => const AccountScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/orders',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) {
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
        path: '/addresses',
        builder: (context, state) => Consumer(
          builder: (context, ref, child) {
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
        path: '/search',
        builder: (context, state) =>
            SearchScreen(initialQuery: state.uri.queryParameters['q'] ?? ''),
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
            final AsyncValue<AuthSession?> authState = ref.watch(
              authControllerProvider,
            );
            if (authState.isLoading) {
              return const _CheckoutAuthLoading();
            }
            final AuthSession? session = authState.asData?.value;
            if (session == null) {
              return const AuthScreen(popOnSuccess: false);
            }
            final CartTokenStore tokenStore = ref.watch(cartTokenStoreProvider);
            return CheckoutScreen(
              repository: StoreApiCheckoutRepository(
                cartRepository: ref.watch(cartRepositoryProvider),
                transport: StoreApiCheckoutTransport.forConfiguredStore(
                  dio: ref.watch(cartDioProvider),
                  authTokenReader: () =>
                      ref.read(authControllerProvider).asData?.value?.token,
                ),
                cartTokenStore: tokenStore,
              ),
              customerEmail: session.user.email,
              onBackToCart: () => context.go('/cart'),
              onOrderSuccess: (_) => ref.invalidate(cartControllerProvider),
              suggestions: ref.watch(checkoutSuggestionsProvider).value ?? const CheckoutSuggestions(),
              onAddSuggestion: ref.read(addProductPurchaseSelectionProvider),
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
      loading: () => SplashScreen(config: ref.watch(splashConfigProvider).value ?? const SplashConfig()),
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
