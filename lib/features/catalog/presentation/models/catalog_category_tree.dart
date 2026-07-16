import 'package:kidia_store_app/features/catalog/domain/entities/catalog_category.dart';

class CatalogCategoryNode {
  const CatalogCategoryNode({
    required this.category,
    this.children = const <CatalogCategoryNode>[],
  });

  final CatalogCategory category;
  final List<CatalogCategoryNode> children;
}

class CatalogCategoryTree {
  const CatalogCategoryTree({
    required this.roots,
    required this.totalCategories,
  });

  final List<CatalogCategoryNode> roots;
  final int totalCategories;

  bool get isEmpty => roots.isEmpty;

  factory CatalogCategoryTree.fromCategories(Iterable<CatalogCategory> source) {
    final Map<int, CatalogCategory> categories = <int, CatalogCategory>{
      for (final CatalogCategory category in source)
        if (category.id > 0) category.id: category,
    };
    final Map<int, List<CatalogCategory>> childrenByParent =
        <int, List<CatalogCategory>>{};

    for (final CatalogCategory category in categories.values) {
      childrenByParent
          .putIfAbsent(category.parentId, () => <CatalogCategory>[])
          .add(category);
    }

    CatalogCategoryNode buildNode(CatalogCategory category, Set<int> ancestry) {
      if (ancestry.contains(category.id)) {
        return CatalogCategoryNode(category: category);
      }

      final Set<int> nextAncestry = <int>{...ancestry, category.id};
      final List<CatalogCategoryNode> children =
          (childrenByParent[category.id] ?? const <CatalogCategory>[])
              .where((CatalogCategory child) => child.id != category.id)
              .map((CatalogCategory child) => buildNode(child, nextAncestry))
              .toList(growable: false);

      return CatalogCategoryNode(
        category: category,
        children: List<CatalogCategoryNode>.unmodifiable(children),
      );
    }

    final List<CatalogCategory> rootCategories = categories.values
        .where(
          (CatalogCategory category) =>
              category.parentId == 0 ||
              !categories.containsKey(category.parentId),
        )
        .toList(growable: true);

    // Corrupt extension data can contain a parent cycle with no natural root.
    // Keep those categories reachable instead of hiding the complete catalog.
    final Set<int> reachable = <int>{};
    void collect(CatalogCategoryNode node) {
      if (!reachable.add(node.category.id)) {
        return;
      }
      for (final CatalogCategoryNode child in node.children) {
        collect(child);
      }
    }

    final List<CatalogCategoryNode> roots = rootCategories
        .map((CatalogCategory category) => buildNode(category, <int>{}))
        .toList(growable: true);
    for (final CatalogCategoryNode root in roots) {
      collect(root);
    }
    for (final CatalogCategory category in categories.values) {
      if (!reachable.contains(category.id)) {
        final CatalogCategoryNode root = buildNode(category, <int>{});
        roots.add(root);
        collect(root);
      }
    }

    return CatalogCategoryTree(
      roots: List<CatalogCategoryNode>.unmodifiable(roots),
      totalCategories: categories.length,
    );
  }
}
