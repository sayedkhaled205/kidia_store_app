import 'package:flutter/material.dart';
import '../../page_builder/domain/cms_page_layout.dart';
import '../application/product_detail_controller.dart';

/// Uses the product's existing option values; never invents size measurements.
class ProductSizeChart extends StatelessWidget {
  const ProductSizeChart({super.key, required this.settings, required this.group,
    required this.selected, required this.onSelected});
  final CmsPageComponent settings;
  final ProductOptionGroup group;
  final String? selected;
  final ValueChanged<String> onSelected;

  Color color(String key, String fallback) {
    final value = settings.string(key, fallback).replaceFirst('#', '');
    final parsed = int.tryParse(value, radix: 16);
    return Color(0xff000000 | (value.length == 6 && parsed != null ? parsed : int.parse(fallback.substring(1), radix: 16)));
  }

  @override
  Widget build(BuildContext context) {
    final textColor = color('text_color', '#1F2933');
    final rowColor = color('row_color', '#F6F8F7');
    final accent = color('accent_color', '#2F806E');
    final rowHeight = settings.number('row_height', 52).clamp(36, 80).toDouble();
    final style = settings.string('layout_style', 'list');
    Widget option(ProductOptionValue option, {bool chip = false}) {
      final active = option.value == selected;
      return Material(
        key: ValueKey('size-chart-option-${option.value}'),
        color: rowColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(style == 'table' ? 0 : 12),
          side: BorderSide(color: active ? accent : Colors.transparent, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: () => onSelected(option.value), child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: rowHeight),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(mainAxisSize: chip ? MainAxisSize.min : MainAxisSize.max, children: [
              Flexible(fit: chip ? FlexFit.loose : FlexFit.tight, child: Text(option.label, style: TextStyle(color: textColor))),
              if (style == 'table' || active) ...[
                const SizedBox(width: 12),
                Icon(active ? Icons.check_circle_rounded : Icons.radio_button_unchecked, color: active ? accent : textColor, size: 20),
              ],
            ]),
          ),
        )),
      );
    }
    return SingleChildScrollView(
      key: const Key('product-size-chart-content'),
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(settings.string('title', 'Size chart'), key: const Key('size-chart-title'),
          style: TextStyle(fontSize: settings.number('title_size', 24).clamp(14, 40).toDouble(), color: textColor, fontWeight: FontWeight.w900)),
        if (settings.boolean('show_description', true)) ...[
          const SizedBox(height: 8),
          Text(settings.string('description', 'Choose the size that fits you best.'), style: TextStyle(color: textColor)),
        ],
        const SizedBox(height: 18),
        if (style == 'chips')
          LayoutBuilder(builder: (context, constraints) => Wrap(key: const Key('size-chart-chips'), spacing: 8, runSpacing: 8,
            children: [for (final item in group.values) ConstrainedBox(constraints: BoxConstraints(maxWidth: constraints.maxWidth), child: option(item, chip: true))]))
        else if (style == 'table')
          Column(key: const Key('size-chart-table'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final item in group.values) ...[option(item), const Divider(height: 1)],
          ])
        else
          Column(key: const Key('size-chart-list'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final item in group.values) Padding(padding: const EdgeInsets.only(bottom: 8), child: option(item)),
          ]),
      ]),
    );
  }
}
