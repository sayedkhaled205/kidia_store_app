import 'package:flutter/material.dart';
import 'package:kidia_store_app/features/catalog/presentation/catalog_copy.dart';
import 'package:kidia_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';
import 'package:kidia_store_app/features/catalog/presentation/pages/catalog_product_list_screen.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  Widget build(BuildContext context) {
    final CatalogCopy copy = CatalogCopy.of(context);
    return CatalogProductListScreen(
      showSearchField: true,
      request: CatalogProductListRequest(
        title: copy.search,
        search: initialQuery,
        searchOnly: true,
      ),
    );
  }
}
