import 'package:flutter/material.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';
import 'package:kidia_store_app/features/home/presentation/widgets/home_block_factory.dart';
import 'package:kidia_store_app/features/home/presentation/widgets/home_block_frame.dart';

class HomeBlockRenderer extends StatelessWidget {
  const HomeBlockRenderer({
    required this.blocks,
    required this.onAction,
    this.keyForBlock,
    super.key,
  });

  final List<HomeBlock> blocks;
  final ValueChanged<HomeAction> onAction;
  final Key Function(String blockId)? keyForBlock;

  @override
  Widget build(BuildContext context) {
    final List<HomeBlock> enabledBlocks = blocks
        .where((HomeBlock block) => block.enabled)
        .toList(growable: false);

    if (enabledBlocks.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyHomeLayoutState(),
      );
    }

    return SliverList.builder(
      itemCount: enabledBlocks.length,
      itemBuilder: (BuildContext context, int index) {
        final HomeBlock block = enabledBlocks[index];

        return KeyedSubtree(
          key: keyForBlock?.call(block.id) ?? ValueKey<String>(block.id),
          child: HomeBlockFrame(
            block: block,
            child: HomeBlockFactory.create(
              block: block,
              onAction: onAction,
            ),
          ),
        );
      },
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
