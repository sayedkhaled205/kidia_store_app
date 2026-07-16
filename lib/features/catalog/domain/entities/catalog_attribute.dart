class CatalogAttributeTerm {
  const CatalogAttributeTerm({
    required this.id,
    required this.name,
    required this.slug,
  });

  final int id;
  final String name;
  final String slug;
}

class CatalogProductAttribute {
  const CatalogProductAttribute({
    required this.id,
    required this.name,
    required this.taxonomy,
    required this.hasVariations,
    required this.terms,
  });

  final int id;
  final String name;
  final String taxonomy;
  final bool hasVariations;
  final List<CatalogAttributeTerm> terms;
}

class CatalogVariationAttribute {
  const CatalogVariationAttribute({
    required this.name,
    required this.value,
    this.taxonomy = '',
  });

  final String name;
  final String value;
  final String taxonomy;
}
