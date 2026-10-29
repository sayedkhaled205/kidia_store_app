import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/shared/widgets/product/store_product_card.dart';
import 'package:mobishop_store_app/shared/widgets/product/store_product_card_data.dart';
import 'home_block_widgets.dart' show HomeBlockTitle;

class SharedHomeProductCollection extends StatelessWidget {
  const SharedHomeProductCollection({
    required this.items,
    required this.settings,
    required this.onAction,
    required this.showViewAll,
    required this.viewAllAction,
    this.title,
    this.subtitle,
    this.viewAllLabel,
    this.columns = 2,
    this.itemWidth,
    super.key,
  });
  final List<HomeProductItem> items;
  final CmsPageComponent settings;
  final ValueChanged<HomeAction> onAction;
  final HomeAction? viewAllAction;
  final String? title, subtitle, viewAllLabel;
  final bool showViewAll;
  final int columns;
  final double? itemWidth;

  @override
  Widget build(BuildContext context) {
    Widget card(HomeProductItem item) => StoreProductCard(
      product: StoreProductCardData.home(item),
      settings: settings,
      fitImageRatio: true,
      onTap: item.action == null ? null : () => onAction(item.action!),
    );
    final data = items.map(StoreProductCardData.home).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          if (title != null)
            HomeBlockTitle(
              title: title!,
              showAction: showViewAll,
              actionLabel:
                  viewAllLabel ??
                  (Localizations.localeOf(context).languageCode == 'ar'
                      ? 'عرض الكل'
                      : 'View all'),
              onPressed: viewAllAction == null
                  ? null
                  : () => onAction(viewAllAction!),
            ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(subtitle!),
            ),
          if (itemWidth != null)
            SizedBox(
              height: data.fold<double>(
                0,
                (height, item) =>
                    math.max(height, _cardHeight(context, item, itemWidth!)),
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, index) =>
                    SizedBox(width: itemWidth, child: card(items[index])),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final count = columns.clamp(1, 4);
                  final width =
                      (constraints.maxWidth - 12 * (count - 1)) / count;
                  final height = data.fold<double>(
                    1,
                    (height, item) =>
                        math.max(height, _cardHeight(context, item, width)),
                  );
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: count,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: height,
                    ),
                    itemBuilder: (_, index) => card(items[index]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  double _cardHeight(
    BuildContext context,
    StoreProductCardData data,
    double width,
  ) {
    final theme = Theme.of(context).textTheme;
    final available = math.max(
      1.0,
      width -
          2 * settings.number('content_horizontal_padding', 12).clamp(0, 24),
    );
    double measure(String text, TextStyle? style, {int lines = 1}) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: lines,
      )..layout(maxWidth: available);
      final height = painter.height;
      painter.dispose();
      return height;
    }

    var height =
        width / settings.number('image_ratio', .9).clamp(.6, 1.8) +
        settings.number('content_top_padding', 10).clamp(0, 24) +
        settings.number('content_bottom_padding', 12).clamp(0, 24);
    if (settings.boolean('show_name', false)) {
      height +=
          measure(
            data.name,
            theme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
            lines: 2,
          ) +
          5;
    }
    if (settings.boolean('show_rating', false) && data.averageRating > 0) {
      height += math.max(16, measure('5.0 (100)', theme.labelSmall)) + 6;
    }
    if (settings.boolean('show_price', true)) {
      final current = measure(
        data.currentPrice,
        theme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: settings.number('price_size', 16).clamp(10, 28).toDouble(),
        ),
      );
      height += current;
      // The same price Wrap can occupy two lines on narrow accessibility layouts.
      if (settings.boolean('show_regular_price', true) && data.isDiscounted) {
        height += measure(data.regularPrice, theme.labelSmall) + 2;
      }
    }
    return height.ceilToDouble();
  }
}
