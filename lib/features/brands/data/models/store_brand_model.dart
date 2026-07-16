import 'package:kidia_store_app/features/brands/domain/entities/store_brand.dart';

class StoreBrandModel {
  const StoreBrandModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.count,
    this.image,
  });

  final int id;
  final String name;
  final String slug;
  final int count;
  final Uri? image;

  factory StoreBrandModel.fromJson(Map<String, dynamic> json) {
    final int id = _integer(json['id']);
    final String name = _string(json['name']);
    final String slug = _string(json['slug']);
    if (id <= 0 || name.isEmpty || slug.isEmpty) {
      throw const FormatException(
        'A brand requires a valid id, name and slug.',
      );
    }

    final dynamic rawImage = json['image'];
    Uri? image;
    if (rawImage is Map) {
      image = _webUri(
        rawImage['thumbnail'] ?? rawImage['src'] ?? rawImage['source'],
      );
    } else {
      image = _webUri(rawImage);
    }

    final int count = _integer(json['count']);
    return StoreBrandModel(
      id: id,
      name: name,
      slug: slug,
      count: count < 0 ? 0 : count,
      image: image,
    );
  }

  StoreBrand toEntity() {
    return StoreBrand(
      id: id,
      name: name,
      slug: slug,
      count: count,
      image: image,
    );
  }

  static int _integer(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _string(dynamic value) => value?.toString().trim() ?? '';

  static Uri? _webUri(dynamic value) {
    final Uri? uri = Uri.tryParse(_string(value));
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri;
  }
}
