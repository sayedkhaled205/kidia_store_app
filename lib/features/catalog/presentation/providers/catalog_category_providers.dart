import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_page.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_category_query.dart';
import 'package:kidia_store_app/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:kidia_store_app/features/catalog/presentation/models/catalog_category_tree.dart';
import 'package:kidia_store_app/features/catalog/presentation/providers/catalog_providers.dart';

final catalogCategoryTreeProvider =
    FutureProvider.autoDispose<CatalogCategoryTree>((Ref ref) async {
      final CatalogRepository repository = ref.watch(catalogRepositoryProvider);
      final List<CatalogCategory> categories = <CatalogCategory>[];
      int pageNumber = 1;

      while (true) {
        final CatalogPage<CatalogCategory> page = await repository
            .getCategories(
              CatalogCategoryQuery(
                page: pageNumber,
                perPage: 100,
                hideEmpty: true,
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

      return CatalogCategoryTree.fromCategories(categories);
    });
