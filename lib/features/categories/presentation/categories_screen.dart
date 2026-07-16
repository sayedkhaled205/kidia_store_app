import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:kidia_store_app/features/catalog/presentation/catalog_copy.dart';
import 'package:kidia_store_app/features/catalog/presentation/models/catalog_category_tree.dart';
import 'package:kidia_store_app/features/catalog/presentation/providers/catalog_category_providers.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CatalogCopy copy = CatalogCopy.of(context);
    final AsyncValue<CatalogCategoryTree> tree = ref.watch(
      catalogCategoryTreeProvider,
    );

    return Scaffold(
      appBar: AppBar(title: Text(copy.categories)),
      body: tree.when(
        loading: _CategoryLoadingList.new,
        error: (Object error, StackTrace stackTrace) => _CategoryStatus(
          icon: Icons.cloud_off_outlined,
          title: copy.connectionError,
          actionLabel: copy.retry,
          onAction: () => ref.invalidate(catalogCategoryTreeProvider),
        ),
        data: (CatalogCategoryTree value) {
          if (value.isEmpty) {
            return _CategoryStatus(
              icon: Icons.category_outlined,
              title: copy.noCategories,
              actionLabel: copy.refresh,
              onAction: () => ref.invalidate(catalogCategoryTreeProvider),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref
                .refresh(catalogCategoryTreeProvider.future)
                .then<void>((CatalogCategoryTree _) {}),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      '${value.totalCategories} ${copy.categories}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: value.roots.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (BuildContext context, int index) =>
                        _CategoryBranch(node: value.roots[index]),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CategoryBranch extends StatefulWidget {
  const _CategoryBranch({required this.node, this.depth = 0});

  final CatalogCategoryNode node;
  final int depth;

  @override
  State<_CategoryBranch> createState() => _CategoryBranchState();
}

class _CategoryBranchState extends State<_CategoryBranch> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final CatalogCategory category = widget.node.category;
    final bool hasChildren = widget.node.children.isNotEmpty;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final CatalogCopy copy = CatalogCopy.of(context);

    final Widget tile = Material(
      color: widget.depth == 0
          ? colors.surfaceContainerLowest
          : Colors.transparent,
      shape: widget.depth == 0
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.outlineVariant),
            )
          : null,
      clipBehavior: widget.depth == 0 ? Clip.antiAlias : Clip.none,
      child: Column(
        children: <Widget>[
          ListTile(
            contentPadding: EdgeInsetsDirectional.fromSTEB(
              widget.depth == 0 ? 12 : 8,
              6,
              8,
              6,
            ),
            leading: _CategoryImage(category: category),
            title: Text(
              category.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            subtitle: category.count > 0
                ? Text(copy.categoryCount(category.count))
                : null,
            onTap: () => _openProducts(context, category),
            trailing: hasChildren
                ? IconButton(
                    tooltip: _expanded ? copy.collapse : copy.expand,
                    onPressed: () => setState(() {
                      _expanded = !_expanded;
                    }),
                    icon: AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const Icon(Icons.keyboard_arrow_down_rounded),
                    ),
                  )
                : const Icon(Icons.chevron_right_rounded),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 2, 12, 14),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: widget.node.children.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.82,
                          ),
                      itemBuilder: (BuildContext context, int index) {
                        final CatalogCategory child =
                            widget.node.children[index].category;
                        return _SubcategoryTile(
                          category: child,
                          onTap: () => _openProducts(context, child),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );

    return tile;
  }

  void _openProducts(BuildContext context, CatalogCategory category) {
    context.push('/categories/${category.id}');
  }
}

class _SubcategoryTile extends StatelessWidget {
  const _SubcategoryTile({required this.category, required this.onTap});

  final CatalogCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String? imageUrl =
        category.image?.thumbnail?.toString() ??
        category.image?.source.toString();
    final Widget fallback = ColoredBox(
      color: colors.secondaryContainer,
      child: Icon(Icons.category_outlined, color: colors.onSecondaryContainer),
    );

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: <Widget>[
            Expanded(
              child: SizedBox.expand(
                child: imageUrl == null || imageUrl.isEmpty
                    ? fallback
                    : AppNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        semanticLabel: category.name,
                        errorWidget: fallback,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
              child: Text(
                category.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryImage extends StatelessWidget {
  const _CategoryImage({required this.category});

  final CatalogCategory category;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String? imageUrl =
        category.image?.thumbnail?.toString() ??
        category.image?.source.toString();
    final Widget fallback = ColoredBox(
      color: colors.secondaryContainer,
      child: Icon(Icons.category_outlined, color: colors.onSecondaryContainer),
    );

    return SizedBox.square(
      dimension: 54,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: imageUrl == null || imageUrl.isEmpty
            ? fallback
            : AppNetworkImage(
                imageUrl: imageUrl,
                semanticLabel: category.name,
                errorWidget: fallback,
              ),
      ),
    );
  }
}

class _CategoryLoadingList extends StatelessWidget {
  const _CategoryLoadingList();

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.surfaceContainer;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 7,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) => Container(
        height: 78,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

class _CategoryStatus extends StatelessWidget {
  const _CategoryStatus({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return RefreshIndicator(
          onRefresh: () async => onAction(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(icon, size: 52, color: colors.primary),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                            ),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.tonalIcon(
                        onPressed: onAction,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(actionLabel),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
