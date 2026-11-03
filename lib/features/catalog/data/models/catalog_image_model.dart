import 'package:mobishop_store_app/features/catalog/data/models/catalog_json.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_image.dart';

class CatalogImageModel extends CatalogImage {
  const CatalogImageModel({
    required super.source,
    super.thumbnail,
    super.cardVariant,
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
      cardVariant: _cardVariant(json['srcset']),
      name: CatalogJson.string(json['name']),
      alt: CatalogJson.string(json['alt']),
    );
  }

  static Uri? _cardVariant(dynamic srcset) {
    if (srcset is! String) return null;
    Uri? selected;
    int? selectedWidth;
    // 1440 physical pixels cover even a full-width 480px phone card at DPR3.
    for (final candidate in srcset.split(',')) {
      final match = RegExp(r'^\s*(\S+)\s+(\d+)w\s*$').firstMatch(candidate);
      if (match == null) continue;
      final width = int.tryParse(match[2]!);
      final uri = CatalogJson.webUri(match[1]);
      if (width != null &&
          width >= 1440 &&
          uri != null &&
          (selectedWidth == null || width < selectedWidth)) {
        selected = uri;
        selectedWidth = width;
      }
    }
    return selected;
  }
}
