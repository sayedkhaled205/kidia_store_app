import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/odoo_customer_providers51.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

class WishlistAccess {
  const WishlistAccess({
    required this.requiresSignIn,
    this.authenticated = false,
    this.loading = false,
    this.expiresAt,
  });
  final bool requiresSignIn;
  final bool authenticated;
  final DateTime? expiresAt;
  bool get signedIn =>
      authenticated &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now().toUtc()));
  final bool loading;
}

/// One access rule for the page, detail action, and every product card.
/// Each platform reads only its own identity graph. Guest access needs no auth.
final wishlistAccessProvider = Provider<WishlistAccess>((ref) {
  if (!AppConfig.isCmsPreview &&
      AppConfig.commercePlatform == CommercePlatform.shopify) {
    return const WishlistAccess(requiresSignIn: false);
  }
  final required =
      ref
          .watch(cmsPageLayoutProvider('wishlist'))
          .value
          ?.string('wishlist_access_mode', 'sign_in_required') !=
      'guest';
  if (!required) return const WishlistAccess(requiresSignIn: false);
  if (!AppConfig.isCmsPreview &&
      AppConfig.commercePlatform == CommercePlatform.odoo) {
    final session = ref.watch(odooCustomerSession51Provider);
    return WishlistAccess(
      requiresSignIn: true,
      loading: session.isLoading,
      authenticated: session.asData?.value.authenticated ?? false,
      expiresAt: session.asData?.value.expiresAt,
    );
  }
  final session = ref.watch(authControllerProvider);
  return WishlistAccess(
    requiresSignIn: true,
    loading: session.isLoading,
    authenticated: session.asData?.value != null,
    expiresAt: session.asData?.value?.expiresAt,
  );
});
