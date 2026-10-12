import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/category_overrides83.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_category.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_image.dart';

void main() {
  test(
    'saved category overrides retain exact hierarchy/order/hiding/public artwork',
    () {
      final direct = <CatalogCategory>[
        const CatalogCategory(
          id: 1,
          name: 'Alpha',
          slug: 'a',
          count: 12,
          fontSize: 19,
        ),
        const CatalogCategory(id: 2, name: 'Beta', slug: 'b'),
        const CatalogCategory(id: 3, name: 'Child', slug: 'c', parentId: 2),
        const CatalogCategory(id: 4, name: 'Moved', slug: 'm'),
        CatalogCategory(
          id: 5,
          name: 'Live',
          slug: 'l',
          image: CatalogImage(
            source: Uri.parse('https://store.example/live.png'),
          ),
        ),
      ];
      Map<String, dynamic> row({
        int? parent,
        int order = 0,
        bool hidden = false,
        int image = 0,
        String name = '',
      }) => {
        'parent_id': parent,
        'display_order': order,
        'hidden': hidden,
        'image_id': image,
        'name': name,
      };
      final overrides = <String, dynamic>{
        '1': row(order: 2, name: 'Saved alias'),
        '2': row(order: 0, hidden: true),
        '4': row(parent: 1, image: 44)
          ..['image_url'] = 'https://media.example/art.png',
        '5': row(order: 1),
      };
      final visible = applySavedCategoryOverrides83(direct, overrides);
      expect(visible.map((c) => c.id), [5, 1, 4]);
      expect(visible[1].name, 'Saved alias');
      expect(visible[1].count, 12);
      expect(visible[1].fontSize, 19);
      expect(visible[2].parentId, 1);
      expect(
        visible[2].image!.source.toString(),
        'https://media.example/art.png',
      );
      expect(visible.first.image, same(direct.last.image));
      expect(
        () => applySavedCategoryOverrides83(direct, {'1': row(image: 44)}),
        throwsFormatException,
      );
      expect(
        () => applySavedCategoryOverrides83(direct, {
          '1': row(image: 44)
            ..['image_url'] = 'https://media.example/art?token=private',
        }),
        throwsFormatException,
      );
      final cycle = applySavedCategoryOverrides83(direct, {
        '1': row(parent: 4),
        '4': row(parent: 1),
      });
      expect(
        cycle.where((c) => c.id == 1 || c.id == 4).map((c) => c.parentId),
        [0, 0],
      );
    },
  );
}
