import 'package:flutter/material.dart';
import 'package:mobishop_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';
import 'catalog_size_sheet.dart';

abstract final class CatalogColorSheet {
  static Future<CatalogColorSelection?> show(
    BuildContext context, {
    required List<CatalogSizeOption> options,
    required CatalogProductFilters selectedFilters,
  }) async {
    final selection = await CatalogSizeSheet.show(
      context,
      options: options,
      selectedFilters: selectedFilters,
      colors: true,
    );
    return selection == null
        ? null
        : CatalogColorSelection(options: selection.options);
  }
}

class CatalogColorSelection {
  const CatalogColorSelection({this.options = const []});
  final List<CatalogSizeOption> options;
}
