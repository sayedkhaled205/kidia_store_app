import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/home/data/models/home_layout_model.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';

void main() {
  group('HomeLayoutModel', () {
    test('parses a valid CMS block', () {
      final layout = HomeLayoutModel.fromJson(<String, dynamic>{
        'version': 4,
        'page': 'home',
        'locale': 'en',
        'updated_at': '2026-07-15T20:00:00Z',
        'blocks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'spacer-1',
            'type': 'spacer',
            'enabled': true,
            'data': <String, dynamic>{'height': 24},
          },
        ],
      });

      expect(layout.blocks, hasLength(1));
      expect(layout.blocks.single, isA<SpacerBlock>());
      expect((layout.blocks.single as SpacerBlock).height, 24);
    });

    test('skips an unsupported block without breaking valid blocks', () {
      final layout = HomeLayoutModel.fromJson(<String, dynamic>{
        'version': 4,
        'page': 'home',
        'locale': 'en',
        'updated_at': '2026-07-15T20:00:00Z',
        'blocks': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'future-1',
            'type': 'future_block',
            'enabled': true,
            'data': <String, dynamic>{},
          },
          <String, dynamic>{
            'id': 'spacer-1',
            'type': 'spacer',
            'enabled': true,
            'data': <String, dynamic>{'height': 16},
          },
        ],
      });

      expect(layout.blocks, hasLength(1));
      expect(layout.blocks.single.id, 'spacer-1');
    });

    test('rejects an invalid layout envelope', () {
      expect(
        () => HomeLayoutModel.fromJson(<String, dynamic>{
          'version': 0,
          'page': 'home',
          'locale': 'en',
          'updated_at': 'not-a-date',
          'blocks': <dynamic>[],
        }),
        throwsFormatException,
      );
    });
  });
}
