import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/search/presentation/search_screen.dart';
import 'app_startup_gate.dart';
import 'main_shell.dart';

abstract final class AppRoutePaths {
  const AppRoutePaths._();

  static const String home = '/';
  static const String product = '/product/:productId';
  static const String category = '/categories/:categoryId';
  static const String products = '/products';
  static const String brands = '/brands';
  static const String search = '/search';
}

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final GoRouter router = GoRouter(
    initialLocation: AppRoutePaths.home,
    routes: <RouteBase>[
      ShellRoute(
        builder: (
          BuildContext context,
          GoRouterState state,
          Widget child,
        ) {
          return AppStartupGate(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: AppRoutePaths.home,
            builder: (BuildContext context, GoRouterState state) {
              return const MainShell();
            },
          ),
          GoRoute(
            path: AppRoutePaths.product,
            builder: (BuildContext context, GoRouterState state) {
              return CmsRouteScreen(
                title: 'المنتج',
                value: state.pathParameters['productId'],
                icon: Icons.inventory_2_outlined,
              );
            },
          ),
          GoRoute(
            path: AppRoutePaths.category,
            builder: (BuildContext context, GoRouterState state) {
              return CmsRouteScreen(
                title: 'القسم',
                value: state.pathParameters['categoryId'],
                icon: Icons.category_outlined,
              );
            },
          ),
          GoRoute(
            path: AppRoutePaths.products,
            builder: (BuildContext context, GoRouterState state) {
              final String? collection =
                  state.uri.queryParameters['collection'];
              final String? brand = state.uri.queryParameters['brand'];

              return CmsRouteScreen(
                title: brand == null ? 'مجموعة المنتجات' : 'منتجات البراند',
                value: brand ?? collection,
                icon: Icons.view_carousel_outlined,
              );
            },
          ),
          GoRoute(
            path: AppRoutePaths.brands,
            builder: (BuildContext context, GoRouterState state) {
              return const CmsRouteScreen(
                title: 'البراندات',
                icon: Icons.workspace_premium_outlined,
              );
            },
          ),
          GoRoute(
            path: AppRoutePaths.search,
            builder: (BuildContext context, GoRouterState state) {
              return const SearchScreen();
            },
          ),
        ],
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) {
      return CmsRouteScreen(
        title: 'الصفحة غير موجودة',
        value: state.uri.toString(),
        icon: Icons.link_off_rounded,
      );
    },
  );

  ref.onDispose(router.dispose);
  return router;
});

class CmsRouteScreen extends StatelessWidget {
  const CmsRouteScreen({
    required this.title,
    required this.icon,
    this.value,
    super.key,
  });

  final String title;
  final String? value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 64),
              const SizedBox(height: 16),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (value != null && value!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  value!,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
