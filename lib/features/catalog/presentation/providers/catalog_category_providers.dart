import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/app_design/app_design_providers58.dart';
import 'package:mobishop_store_app/core/app_design/category_overrides83.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:mobishop_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:mobishop_store_app/features/catalog/domain/repositories/catalog_change_source.dart';
import 'package:mobishop_store_app/features/catalog/presentation/models/catalog_category_tree.dart';
import 'package:mobishop_store_app/features/catalog/presentation/providers/catalog_providers.dart';

// Bumped on every Categories footer tap so the category screen can reset its
// drilldown/expansion state without refetching the catalog tree.
final categoryEntryRevisionProvider = NotifierProvider<CategoryEntryRevision, int>(CategoryEntryRevision.new);
class CategoryEntryRevision extends Notifier<int> {
  @override
  int build() => 0;
  void enter() => state++;
}

final catalogCategoryTreeProvider =
    FutureProvider.autoDispose<CatalogCategoryTree>((Ref ref) async {
      final CatalogRepository repository = ref.watch(catalogRepositoryProvider);
      if (repository is CatalogChangeSource) {
        final StreamSubscription<int> changes =
            (repository as CatalogChangeSource).catalogChanges.listen(
              (_) => ref.invalidateSelf(),
            );
        ref.onDispose(changes.cancel);
      }
      final List<CatalogCategory> categories = <CatalogCategory>[];
      int pageNumber = 1;

      while (true) {
        final CatalogPage<CatalogCategory> page = await repository
            .getCategories(
              CatalogCategoryQuery(
                page: pageNumber,
                perPage: 100,
                // Foreign public catalogs do not implement hideEmpty. Read
                // their real categories/collections, never invent filtering.
                hideEmpty:
                    AppConfig.commercePlatform == CommercePlatform.wooCommerce,
              ),
            );
        categories.addAll(page.items);

        if (!page.hasNextPage || page.items.isEmpty) {
          break;
        }

        pageNumber++;
        if (pageNumber > 200) {
          throw StateError(
            'The store exposes too many category pages to build safely.',
          );
        }
      }

      final saved = ref
          .watch(portableAppDesign58Provider)
          ?.pageLayout('category')
          .settings['category_overrides'];
      return CatalogCategoryTree.fromCategories(
        saved is Map
            ? applySavedCategoryOverrides83(
                categories,
                Map<String, dynamic>.from(saved),
                allowUnresolvedImages: AppConfig.commercePlatform == CommercePlatform.wooCommerce,
              )
            : categories,
      );
    });
