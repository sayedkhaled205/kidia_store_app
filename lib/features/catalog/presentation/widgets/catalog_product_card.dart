import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/shared/widgets/product/shared_product_card_provider.dart';
import 'package:mobishop_store_app/shared/widgets/product/store_product_card.dart';
import 'package:mobishop_store_app/shared/widgets/product/store_product_card_data.dart';

class CatalogProductCard extends ConsumerWidget {
  const CatalogProductCard({
    required this.product,
    required this.onTap,
    this.settings,
    this.fitImageRatio = false,
    this.wishlistAction,
    super.key,
  });
  final CatalogProduct product;
  final VoidCallback? onTap;
  final CmsPageComponent? settings;
  final bool fitImageRatio;
  final Widget? wishlistAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shared = ref.watch(sharedProductCardProvider);
    return StoreProductCard(
      product: StoreProductCardData.catalog(product, shared: shared != null),
      onTap: onTap,
      settings: shared ?? settings,
      fitImageRatio: fitImageRatio,
      wishlistAction: wishlistAction,
    );
  }
}
