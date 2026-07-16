import 'package:flutter/material.dart';
import 'package:kidia_store_app/features/catalog/domain/queries/catalog_product_query.dart';
import 'package:kidia_store_app/features/catalog/presentation/catalog_copy.dart';

abstract final class CatalogSortSheet {
  static const List<CatalogSort> options = <CatalogSort>[
    CatalogSort.relevance,
    CatalogSort.newest,
    CatalogSort.priceLowToHigh,
    CatalogSort.priceHighToLow,
    CatalogSort.popularity,
    CatalogSort.rating,
    CatalogSort.name,
  ];

  static Future<CatalogSort?> show(
    BuildContext context, {
    required CatalogSort selected,
  }) {
    final CatalogCopy copy = CatalogCopy.of(context);
    return showModalBottomSheet<CatalogSort>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 8),
              child: Text(
                copy.sort,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            for (final CatalogSort option in options)
              ListTile(
                title: Text(copy.sortLabel(option)),
                leading: Icon(
                  option == selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                ),
                selected: option == selected,
                onTap: () => Navigator.of(context).pop(option),
              ),
          ],
        ),
      ),
    );
  }
}
