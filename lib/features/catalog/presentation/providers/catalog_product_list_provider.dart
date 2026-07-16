import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';
import 'package:kidia_store_app/features/catalog/presentation/providers/catalog_providers.dart';

final catalogProductListControllerProvider = Provider.autoDispose
    .family<CatalogProductListController, CatalogProductListRequest>((
      Ref ref,
      CatalogProductListRequest request,
    ) {
      final CatalogProductListController controller =
          CatalogProductListController(
            ref.watch(catalogRepositoryProvider),
            request: request,
          );
      ref.onDispose(controller.dispose);

      if (!controller.isAwaitingSearch) {
        unawaited(controller.loadInitial());
      }

      return controller;
    });
