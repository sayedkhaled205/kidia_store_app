import 'package:flutter/material.dart';
import 'package:mobishop_store_app/features/catalog/presentation/catalog_copy.dart';
import 'package:mobishop_store_app/features/catalog/presentation/controllers/catalog_product_list_controller.dart';
import 'catalog_toolbar_panel.dart';

abstract final class CatalogSizeSheet {
  static Future<CatalogSizeSelection?> show(
    BuildContext context, {
    required List<CatalogSizeOption> options,
    required CatalogProductFilters selectedFilters,
    bool belowToolbar = false,
    bool colors = false,
  }) {
    Widget panel(BuildContext context) => _CatalogOptionPanel(
      options: options,
      initialSelection: colors ? selectedFilters.colors : selectedFilters.sizes,
      colors: colors,
      showTitle: !belowToolbar,
    );
    if (belowToolbar) {
      return showCatalogToolbarPanel<CatalogSizeSelection>(
        context,
        builder: panel,
      );
    }
    return showModalBottomSheet<CatalogSizeSelection>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: panel,
    );
  }
}

class CatalogSizeSelection {
  const CatalogSizeSelection({this.options = const []});
  final List<CatalogSizeOption> options;
}

class _CatalogOptionPanel extends StatefulWidget {
  const _CatalogOptionPanel({
    required this.options,
    required this.initialSelection,
    required this.colors,
    required this.showTitle,
  });
  final List<CatalogSizeOption> options;
  final List<CatalogSizeOption> initialSelection;
  final bool colors;
  final bool showTitle;
  @override
  State<_CatalogOptionPanel> createState() => _CatalogOptionPanelState();
}

class _CatalogOptionPanelState extends State<_CatalogOptionPanel> {
  late final Map<String, CatalogSizeOption> _selected = {
    for (final option in widget.initialSelection) option.key: option,
  };
  @override
  Widget build(BuildContext context) {
    final copy = CatalogCopy.of(context);
    final theme = Theme.of(context);
    final options = <String, CatalogSizeOption>{
      for (final option in widget.initialSelection) option.key: option,
      for (final option in widget.options) option.key: option,
    }.values;
    final prefix = widget.colors ? 'catalog-color' : 'catalog-size';
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(42)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 14)),
    );
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .55,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showTitle) ...[
                Text(
                  widget.colors ? copy.chooseColor : copy.chooseSize,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Flexible(
                child: SingleChildScrollView(
                  child: options.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            widget.colors ? copy.noColors : copy.noSizes,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            for (final option in options)
                              FilterChip(
                                key: Key(
                                  '$prefix-${option.taxonomy}-${option.term}',
                                ),
                                label: Text(option.label),
                                labelStyle: theme.textTheme.labelLarge
                                    ?.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _selected.containsKey(option.key)
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurface,
                                    ),
                                avatar:
                                    widget.colors &&
                                        _color(option.label) != null
                                    ? Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _color(option.label),
                                          border: Border.all(
                                            color: theme
                                                .colorScheme
                                                .outlineVariant,
                                          ),
                                        ),
                                      )
                                    : null,
                                selected: _selected.containsKey(option.key),
                                showCheckmark: false,
                                visualDensity: const VisualDensity(
                                  horizontal: -2,
                                  vertical: -1,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                backgroundColor: theme.colorScheme.surface,
                                selectedColor: theme.colorScheme.primary
                                    .withValues(alpha: .08),
                                side: BorderSide(
                                  color: _selected.containsKey(option.key)
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.outlineVariant,
                                  width: _selected.containsKey(option.key)
                                      ? 1.5
                                      : 1,
                                ),
                                onSelected: (value) => setState(() {
                                  if (value) {
                                    _selected[option.key] = option;
                                  } else {
                                    _selected.remove(option.key);
                                  }
                                }),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: Key('$prefix-reset'),
                      style: buttonStyle,
                      onPressed: () => setState(_selected.clear),
                      child: Text(copy.reset),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: Key('$prefix-apply'),
                      style: buttonStyle,
                      onPressed: () => Navigator.of(context).pop(
                        CatalogSizeSelection(
                          options: List.unmodifiable(_selected.values),
                        ),
                      ),
                      child: Text(copy.apply),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color? _color(String label) => switch (label.trim().toLowerCase()) {
    'red' || 'أحمر' || 'احمر' => const Color(0xFFE47782),
    'orange' || 'برتقالي' => const Color(0xFFEBA24E),
    'pink' || 'وردي' || 'بينك' => const Color(0xFFDA88B8),
    'brown' || 'بني' => const Color(0xFFAA7662),
    'yellow' || 'أصفر' || 'اصفر' => const Color(0xFFE5CC63),
    'blue' || 'أزرق' || 'ازرق' => const Color(0xFF83ADD6),
    'green' || 'أخضر' || 'اخضر' => const Color(0xFF85B995),
    'white' || 'أبيض' || 'ابيض' => Colors.white,
    'black' || 'أسود' || 'اسود' => Colors.black,
    'grey' || 'gray' || 'رمادي' => Colors.grey,
    _ => null,
  };
}
