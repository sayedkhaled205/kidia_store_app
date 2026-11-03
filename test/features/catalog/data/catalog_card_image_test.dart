import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/catalog/data/models/catalog_image_model.dart';

void main() {
  test(
    'cards use an advertised sharp variant while details keep the original',
    () {
      final image = CatalogImageModel.tryParse({
        'src': 'https://cdn.example/original.jpg?quality=100',
        'thumbnail': 'https://cdn.example/tiny.jpg',
        'srcset':
            'https://cdn.example/tiny.jpg 300w, https://cdn.example/large.jpg?v=2 1536w, https://cdn.example/original.jpg?quality=100 2048w',
      })!;
      expect(image.cardSource.toString(), 'https://cdn.example/large.jpg?v=2');
      expect(
        image.source.toString(),
        'https://cdn.example/original.jpg?quality=100',
      );
    },
  );
  test('missing, small and invalid variants retain original quality', () {
    for (final srcset in [
      null,
      '',
      'https://cdn.example/thumb.jpg 300w',
      'javascript:alert(1) 1536w',
      'not a srcset',
    ]) {
      final image = CatalogImageModel.tryParse({
        'src': 'https://cdn.example/full.jpg',
        'srcset': srcset,
      })!;
      expect(image.cardSource, image.source);
    }
  });
}
