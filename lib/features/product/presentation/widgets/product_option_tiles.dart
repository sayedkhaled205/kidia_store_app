import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobishop_store_app/features/product/application/product_detail_controller.dart';
import 'package:mobishop_store_app/shared/widgets/common/app_network_image.dart';

/// Compact, source-backed color thumbnails and a responsive six-column size row.
/// Selection and availability remain owned by the product controller.
class ProductOptionTiles extends StatelessWidget {
  const ProductOptionTiles({
    required this.controller,
    required this.group,
    this.height = 52,
    this.radius = 8,
    super.key,
  });
  final ProductDetailController controller;
  final ProductOptionGroup group;
  final double height, radius;

  static bool isColor(ProductOptionGroup group) =>
      RegExp(
        r'(^|\s)(colou?r|colou?rs|لون|اللون|ألوان|الوان|الألوان|الالوان)(\s|$)',
      ).hasMatch(
        '${group.key} ${group.label}'.toLowerCase().replaceAll(
          RegExp('[_-]'),
          ' ',
        ),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final selected = controller.selectedAttributes[group.key];
    final colorGroup = isColor(group);
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final minimum = 44 * scale.clamp(1, 1.6);
        final columns = ((constraints.maxWidth + gap) / (minimum + gap))
            .floor()
            .clamp(1, 6);
        final width = colorGroup
            ? 56.0
            : math.min(
                48.0 * scale.clamp(1, 1.6),
                (constraints.maxWidth - gap * (columns - 1)) / columns,
              );
        final tileHeight = colorGroup ? 72.0 : height * scale.clamp(1, 1.8);
        return Wrap(
          spacing: gap,
          runSpacing: 6,
          children: [
            for (final option in group.values)
              Builder(
                builder: (context) {
                  final available = controller.isOptionAvailable(
                    group.key,
                    option.value,
                  );
                  final active = selected == option.value;
                  final image = colorGroup
                      ? controller.imageForOption(group.key, option.value)
                      : null;
                  final label = Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        option.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: available
                              ? colors.onSurface
                              : colors.onSurface.withValues(alpha: .35),
                        ),
                      ),
                    ),
                  );
                  return Semantics(
                    button: true,
                    selected: active,
                    enabled: available,
                    label: option.label,
                    child: Tooltip(
                      message: option.label,
                      child: SizedBox(
                        key: Key('product-option-${group.key}-${option.value}'),
                        width: width,
                        height: tileHeight,
                        child: Material(
                          color: active
                              ? colors.primary.withValues(alpha: .10)
                              : colors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(radius),
                            side: BorderSide(
                              color: active
                                  ? colors.primary
                                  : colors.outlineVariant,
                              width: active ? 1.5 : .8,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: available
                                ? () => controller.selectOption(
                                    group.key,
                                    option.value,
                                  )
                                : null,
                            child: ExcludeSemantics(
                              child: image == null
                                  ? label
                                  : Opacity(
                                      opacity: available ? 1 : .35,
                                      child: Padding(
                                        padding: const EdgeInsets.all(3),
                                        child: AppNetworkImage(
                                          imageUrl: image.source.toString(),
                                          fit: BoxFit.cover,
                                          borderRadius: BorderRadius.circular(
                                            math.max(0, radius - 3),
                                          ),
                                          errorWidget: label,
                                          placeholder: label,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
