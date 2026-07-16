import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/core/network/store_api_client.dart';
import 'package:kidia_store_app/core/network/store_api_exception.dart';
import 'package:kidia_store_app/features/brands/domain/entities/store_brand.dart';
import 'package:kidia_store_app/features/brands/presentation/brands_screen.dart';
import 'package:kidia_store_app/features/brands/presentation/providers/brands_providers.dart';

void main() {
  testWidgets('renders real response data and emits onBrandTap', (
    WidgetTester tester,
  ) async {
    final _BrandsClient client = _BrandsClient();
    StoreBrand? selected;
    await tester.pumpWidget(
      _testApp(
        client,
        BrandsScreen(onBrandTap: (StoreBrand value) => selected = value),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nike'), findsOneWidget);
    await tester.tap(find.text('Nike'));
    expect(selected?.id, 7);

    await tester.enterText(find.byType(TextField), 'puma');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(client.queries.last?['search'], 'puma');
    expect(find.text('Puma'), findsOneWidget);
  });

  testWidgets('shows an explicit unsupported state for a 404 route', (
    WidgetTester tester,
  ) async {
    final _BrandsClient client = _BrandsClient(unsupported: true);
    await tester.pumpWidget(
      _testApp(client, BrandsScreen(onBrandTap: (StoreBrand value) {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Brands are not supported by this store'), findsOneWidget);
    expect(
      find.textContaining('does not expose the Brands API'),
      findsOneWidget,
    );
  });
}

Widget _testApp(StoreApiClient client, Widget home) {
  return ProviderScope(
    overrides: [brandsStoreApiClientProvider.overrideWithValue(client)],
    child: MaterialApp(locale: const Locale('en'), home: home),
  );
}

class _BrandsClient implements StoreApiClient {
  _BrandsClient({this.unsupported = false});

  final bool unsupported;
  final List<Map<String, dynamic>?> queries = <Map<String, dynamic>?>[];

  @override
  Future<StoreApiResponse> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    queries.add(queryParameters);
    if (unsupported) {
      throw const StoreApiException(
        kind: StoreApiFailureKind.notFound,
        message: 'Not found',
        statusCode: 404,
      );
    }
    final bool puma = queryParameters?['search'] == 'puma';
    return StoreApiResponse(
      data: <dynamic>[
        <String, dynamic>{
          'id': puma ? 8 : 7,
          'name': puma ? 'Puma' : 'Nike',
          'slug': puma ? 'puma' : 'nike',
          'count': puma ? 2 : 5,
        },
      ],
      headers: const <String, List<String>>{
        'x-wp-total': <String>['1'],
        'x-wp-totalpages': <String>['1'],
      },
    );
  }
}
