import 'package:mobishop_store_app/features/page_builder/presentation/widgets/preview_edit_region.dart';
import 'package:flutter/material.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:mobishop_store_app/features/home/presentation/widgets/home_block_factory.dart';
import 'package:mobishop_store_app/features/home/presentation/widgets/home_block_frame.dart';
import 'kids_home_product_feed.dart';

class HomeBlockRenderer extends StatelessWidget {
  const HomeBlockRenderer({
    required this.blocks,
    required this.onAction,
    this.keyForBlock,
    this.scrollController,
    super.key,
  });

  final List<HomeBlock> blocks;
  final ValueChanged<HomeAction> onAction;
  final Key Function(String blockId)? keyForBlock;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final List<HomeBlock> enabledBlocks = blocks
        .where(
          (HomeBlock block) =>
              block.enabled &&
              // Hydration has completed here. A successful collection with
              // no matches must not reserve a carousel's height or frame
              // spacing. Failed requests remain CatalogUnavailableBlock so
              // their retry action stays visible.
              (AppConfig.isCmsPreview ||
                  switch (block) {
                    ProductCarouselBlock products => products.items.isNotEmpty,
                    ProductGridBlock products => products.items.isNotEmpty,
                    _ => true,
                  }),
        )
        .toList(growable: false);

    if (enabledBlocks.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyHomeLayoutState(),
      );
    }

    Widget buildBlock(HomeBlock block) {
      return KeyedSubtree(
        key: keyForBlock?.call(block.id) ?? ValueKey<String>(block.id),
        child: PreviewEditRegion(page: 'home', target: block.id, child: HomeBlockFrame(
          block: block,
          child: AppConfig.isCmsPreview && _emptyProductSection(block)
              ? _PreviewEmptyProducts(block: block)
              : block is ProductGridBlock &&
                    block.loadAll &&
                    scrollController != null
              ? KidsHomeProductFeed(
                  block: block,
                  scrollController: scrollController!,
                  onAction: onAction,
                )
              : HomeBlockFactory.create(block: block, onAction: onAction),
        )),
      );
    }

    // Editor selection needs exact geometry for distant sections immediately.
    // Sliver adapters keep all section keys mounted without guessing offsets.
    // Installed apps retain the lazy list and its normal memory behavior.
    if (AppConfig.isCmsPreview) {
      return SliverMainAxisGroup(
        slivers: [
          for (final block in enabledBlocks)
            SliverToBoxAdapter(child: buildBlock(block)),
        ],
      );
    }
    return SliverList.builder(
      itemCount: enabledBlocks.length,
      itemBuilder: (_, index) => buildBlock(enabledBlocks[index]),
    );
  }
}

bool _emptyProductSection(HomeBlock block) => switch (block) {
  ProductCarouselBlock products => products.items.isEmpty,
  ProductGridBlock products => products.items.isEmpty,
  _ => false,
};

// Keep an editor target even when its collection is empty or still loading.
// This is editor-only: installed apps continue to omit empty collections.
class _PreviewEmptyProducts extends StatelessWidget {
  const _PreviewEmptyProducts({required this.block});

  final HomeBlock block;

  @override
  Widget build(BuildContext context) {
    final title = switch (block) {
      ProductCarouselBlock products => products.title,
      ProductGridBlock products => products.title,
      _ => null,
    };
    final arabic = Directionality.of(context) == TextDirection.rtl;
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title?.trim().isNotEmpty == true
                ? title!
                : (arabic ? 'المنتجات' : 'Products'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(minHeight: 104),
            padding: const EdgeInsets.all(16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              arabic
                  ? 'لا توجد منتجات متاحة للمعاينة في هذا القسم حاليًا.'
                  : 'No products are available to preview in this section yet.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHomeLayoutState extends StatelessWidget {
  const _EmptyHomeLayoutState();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.widgets_outlined,
              size: 56,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد أقسام متاحة حاليًا',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'ستظهر محتويات الصفحة الرئيسية هنا عند توفرها.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
