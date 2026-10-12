import 'package:flutter/material.dart';
import 'package:mobishop_store_app/features/catalog/presentation/catalog_copy.dart';
import 'package:mobishop_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';

abstract final class CatalogColorSheet {
  static Future<CatalogColorSelection?> show(
    BuildContext context, {
    required List<CatalogSizeOption> options,
    required CatalogProductFilters selectedFilters,
  }) {
    final CatalogCopy copy = CatalogCopy.of(context);
    return showModalBottomSheet<CatalogColorSelection>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 10),
              child: Text(
                copy.chooseColor,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (options.isEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 28),
                child: Text(
                  copy.noColors,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 12, 16),
                  children: <Widget>[
                    ListTile(
                      key: const Key('catalog-color-all'),
                      title: Text(copy.allColors),
                      leading: Icon(
                        selectedFilters.hasColor
                            ? Icons.radio_button_off_rounded
                            : Icons.radio_button_checked_rounded,
                      ),
                      selected: !selectedFilters.hasColor,
                      onTap: () => Navigator.of(
                        context,
                      ).pop(const CatalogColorSelection()),
                    ),
                    for (final CatalogSizeOption option in options)
                      ListTile(
                        key: Key(
                          'catalog-color-${option.taxonomy}-${option.term}',
                        ),
                        title: Text(option.label),
                        leading: Icon(
                          selectedFilters.colorTaxonomy == option.taxonomy &&
                                  selectedFilters.colorTerm == option.term
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_off_rounded,
                        ),
                        selected:
                            selectedFilters.colorTaxonomy == option.taxonomy &&
                            selectedFilters.colorTerm == option.term,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(CatalogColorSelection(option: option)),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CatalogColorSelection {
  const CatalogColorSelection({this.option});

  final CatalogSizeOption? option;
}
