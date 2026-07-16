import 'package:kidia_store_app/features/catalog/data/models/catalog_json.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_attribute.dart';

abstract final class CatalogAttributeModel {
  const CatalogAttributeModel._();

  static CatalogProductAttribute? tryParseProduct(dynamic value) {
    final Map<String, dynamic>? json = CatalogJson.object(value);
    if (json == null) {
      return null;
    }

    final String name = CatalogJson.string(json['name']);
    final String taxonomy = CatalogJson.string(json['taxonomy']);
    if (name.isEmpty && taxonomy.isEmpty) {
      return null;
    }

    final List<CatalogAttributeTerm> terms = <CatalogAttributeTerm>[];
    for (final dynamic rawTerm in CatalogJson.list(json['terms'])) {
      final Map<String, dynamic>? term = CatalogJson.object(rawTerm);
      if (term == null) {
        continue;
      }
      final String termName = CatalogJson.string(term['name']);
      final String termSlug = CatalogJson.string(term['slug']);
      if (termName.isEmpty && termSlug.isEmpty) {
        continue;
      }
      terms.add(
        CatalogAttributeTerm(
          id: CatalogJson.integer(term['id']),
          name: termName.isEmpty ? termSlug : termName,
          slug: termSlug.isEmpty ? termName : termSlug,
        ),
      );
    }

    return CatalogProductAttribute(
      id: CatalogJson.integer(json['id']),
      name: name.isEmpty ? taxonomy : name,
      taxonomy: taxonomy,
      hasVariations: CatalogJson.boolean(json['has_variations']),
      terms: List<CatalogAttributeTerm>.unmodifiable(terms),
    );
  }

  static CatalogVariationAttribute? tryParseVariation(dynamic value) {
    final Map<String, dynamic>? json = CatalogJson.object(value);
    if (json == null) {
      return null;
    }

    final String name = CatalogJson.string(json['name']);
    final String taxonomy = CatalogJson.string(json['taxonomy']);
    final String attributeValue = CatalogJson.string(
      json['value'] ?? json['term'] ?? json['slug'],
    );
    if ((name.isEmpty && taxonomy.isEmpty) || attributeValue.isEmpty) {
      return null;
    }

    return CatalogVariationAttribute(
      name: name.isEmpty ? taxonomy : name,
      taxonomy: taxonomy,
      value: attributeValue,
    );
  }
}
