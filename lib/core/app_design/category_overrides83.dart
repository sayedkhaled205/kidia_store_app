import '../../features/catalog/domain/entities/catalog_category.dart';
import '../../features/catalog/domain/entities/catalog_image.dart';

/// Saved presentation only; live categories still come directly from the
/// platform. This mirrors the installed category-page presentation algorithm.
void validateSavedCategoryOverrides83(
  Map<String, dynamic> overrides, {
  bool allowUnresolvedImages = false,
}) {
  for (final entry in overrides.entries) {
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(entry.key) ||
        int.tryParse(entry.key) == null ||
        entry.value is! Map) {
      throw const FormatException('Invalid saved category presentation.');
    }
    final value = Map<String, dynamic>.from(entry.value as Map);
    const required = {
      'parent_id',
      'display_order',
      'hidden',
      'image_id',
      'name',
    };
    const optional = {'image_url', 'image_thumbnail_url'};
    if (required.any((key) => !value.containsKey(key)) ||
        value.keys.any(
          (key) => !required.contains(key) && !optional.contains(key),
        ) ||
        (value['parent_id'] != null &&
            (value['parent_id'] is! int || value['parent_id'] < 0)) ||
        value['display_order'] is! int ||
        value['display_order'] < 0 ||
        value['image_id'] is! int ||
        value['image_id'] < 0 ||
        value['hidden'] is! bool ||
        value['name'] is! String ||
        (value['name'] as String).length > 500) {
      throw const FormatException('Invalid saved category presentation.');
    }
    for (final key in optional) {
      if (value.containsKey(key)) _publicImage(value[key]);
    }
    if (value['image_id'] > 0 &&
        !allowUnresolvedImages &&
        !value.containsKey('image_url')) {
      throw const FormatException(
        'Saved category artwork requires its resolved public media URL.',
      );
    }
  }
}

List<CatalogCategory> applySavedCategoryOverrides83(
  List<CatalogCategory> source,
  Map<String, dynamic> overrides, {
  bool allowUnresolvedImages = false,
}) {
  validateSavedCategoryOverrides83(overrides, allowUnresolvedImages: allowUnresolvedImages);
  final originals = {for (final category in source) category.id: category};
  Map<String, dynamic> setting(int id) => overrides['$id'] is Map
      ? Map<String, dynamic>.from(overrides['$id'] as Map)
      : const {};
  final parents = {
    for (final category in source)
      category.id:
          setting(category.id)['parent_id'] as int? ?? category.parentId,
  };
  // The source resets missing/cyclic saved ancestry to root before hiding or
  // sorting. Do not invent another hierarchy or silently drop the category.
  final normalizedParents = <int, int>{};
  for (final id in parents.keys) {
    var parent = parents[id]!;
    var cursor = parent;
    final seen = {id};
    while (cursor != 0) {
      if (!seen.add(cursor) || !parents.containsKey(cursor)) {
        parent = 0;
        break;
      }
      cursor = parents[cursor]!;
    }
    normalizedParents[id] = parent;
  }
  final siblings = <int, List<CatalogCategory>>{};
  for (final category in source) {
    siblings
        .putIfAbsent(normalizedParents[category.id]!, () => [])
        .add(category);
  }
  for (final list in siblings.values) {
    list.sort((a, b) {
      final left = setting(a.id)['display_order'] as int?;
      final right = setting(b.id)['display_order'] as int?;
      if (left != right) {
        if (left == null) return 1;
        if (right == null) return -1;
        return left.compareTo(right);
      }
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return byName == 0 ? a.id.compareTo(b.id) : byName;
    });
  }
  final result = <CatalogCategory>[];
  void append(int parent, bool ancestorHidden) {
    for (final category in siblings[parent] ?? const <CatalogCategory>[]) {
      final saved = setting(category.id);
      final hidden = ancestorHidden || saved['hidden'] == true;
      if (!hidden) {
        final alias = saved['name'] as String? ?? '';
        final image = saved['image_id'] is int && saved['image_id'] > 0 && saved.containsKey('image_url')
            ? CatalogImage(
                source: _publicImage(saved['image_url']),
                thumbnail: saved.containsKey('image_thumbnail_url')
                    ? _publicImage(saved['image_thumbnail_url'])
                    : null,
              )
            : category.image;
        result.add(
          CatalogCategory(
            id: category.id,
            name: alias.trim().isEmpty ? category.name : alias,
            slug: category.slug,
            parentId: normalizedParents[category.id]!,
            description: category.description,
            count: category.count,
            image: image,
            permalink: category.permalink,
          ).withPresentation(originals[category.id]!),
        );
      }
      append(category.id, hidden);
    }
  }

  append(0, false);
  return List.unmodifiable(result);
}

Uri _publicImage(Object? value) {
  final uri = value is String ? Uri.tryParse(value) : null;
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.queryParameters.keys.any(
        (key) => RegExp(
          r'password|secret|credential|token|csrf|session|authorization|api_?key',
          caseSensitive: false,
        ).hasMatch(key),
      )) {
    throw const FormatException(
      'Saved category artwork needs public HTTPS media.',
    );
  }
  return uri;
}
