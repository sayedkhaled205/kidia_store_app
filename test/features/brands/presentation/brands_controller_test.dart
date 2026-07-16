import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/brands/domain/entities/store_brand.dart';
import 'package:kidia_store_app/features/brands/domain/repositories/brands_repository.dart';
import 'package:kidia_store_app/features/brands/presentation/controllers/brands_controller.dart';

void main() {
  test('loads, searches and appends unique brands', () async {
    final _FakeBrandsRepository repository = _FakeBrandsRepository();
    final BrandsController controller = BrandsController(
      repository,
      pageSize: 2,
    );

    await controller.loadInitial();
    expect(controller.state.items.map((StoreBrand item) => item.id), <int>[
      1,
      2,
    ]);
    expect(controller.state.hasNextPage, isTrue);

    await controller.loadMore();
    expect(controller.state.items.map((StoreBrand item) => item.id), <int>[
      1,
      2,
      3,
    ]);

    await controller.submitSearch(' nike ');
    expect(repository.searches.last, 'nike');
    expect(controller.state.search, 'nike');
    controller.dispose();
  });
}

class _FakeBrandsRepository implements BrandsRepository {
  final List<String> searches = <String>[];

  @override
  Future<StoreBrandPage> getBrands({
    required int page,
    required int perPage,
    required String search,
  }) async {
    searches.add(search);
    if (search.isNotEmpty) {
      return const StoreBrandPage(
        items: <StoreBrand>[
          StoreBrand(id: 1, name: 'Nike', slug: 'nike', count: 4),
        ],
        page: 1,
        perPage: 2,
        totalItems: 1,
        totalPages: 1,
      );
    }
    return StoreBrandPage(
      items: page == 1
          ? const <StoreBrand>[
              StoreBrand(id: 1, name: 'Nike', slug: 'nike', count: 4),
              StoreBrand(id: 2, name: 'Puma', slug: 'puma', count: 3),
            ]
          : const <StoreBrand>[
              StoreBrand(id: 2, name: 'Puma', slug: 'puma', count: 3),
              StoreBrand(id: 3, name: 'Adidas', slug: 'adidas', count: 2),
            ],
      page: page,
      perPage: perPage,
      totalItems: 3,
      totalPages: 2,
    );
  }
}
