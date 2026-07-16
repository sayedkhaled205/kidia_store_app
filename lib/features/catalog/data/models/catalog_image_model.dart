import 'package:kidia_store_app/features/catalog/data/models/catalog_json.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_image.dart';

class CatalogImageModel extends CatalogImage {
  const CatalogImageModel({
    required super.source,
    super.thumbnail,
    super.name,
    super.alt,
  });

  static CatalogImageModel? tryParse(dynamic value) {
    final Map<String, dynamic>? json = CatalogJson.object(value);
    if (json == null) {
      return null;
    }

    final Uri? source = CatalogJson.webUri(json['src'] ?? json['source']);
    if (source == null) {
      return null;
    }

    return CatalogImageModel(
      source: source,
      thumbnail: CatalogJson.webUri(json['thumbnail']),
      name: CatalogJson.string(json['name']),
      alt: CatalogJson.string(json['alt']),
    );
  }
}
