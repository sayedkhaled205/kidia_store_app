import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/catalog/domain/entities/catalog_product.dart';
import 'package:mobishop_store_app/features/product/application/product_detail_controller.dart';
import 'package:mobishop_store_app/features/product/presentation/widgets/product_availability_refresh.dart';

import '../support/product_test_data.dart';

void main() {
  testWidgets('visible stock recovers and expires without reopening the product', (tester) async {
    final repository = ProductFakeCatalogRepository();
    final controller = ProductDetailController(repository: repository, productId: simpleProduct.id);
    addTearDown(controller.dispose);
    await controller.load();
    controller.setQuantity(2);
    await tester.pumpWidget(MaterialApp(home: ProductAvailabilityRefresh(
      controller: controller, child: const SizedBox(),
    )));
    repository.product = CatalogProduct(
      id: simpleProduct.id, name: simpleProduct.name, slug: simpleProduct.slug,
      type: 'simple', prices: simpleProduct.prices, isPurchasable: true,
      isInStock: false,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(controller.canAddToCart, isFalse);
    expect(controller.quantity, 2);
    repository.product = simpleProduct;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(controller.canAddToCart, isTrue);
    expect(controller.quantity, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background reads stop while paused and reconcile on resume', (tester) async {
    final repository = ProductFakeCatalogRepository();
    final controller = ProductDetailController(repository: repository, productId: simpleProduct.id);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(MaterialApp(home: ProductAvailabilityRefresh(
      controller: controller, child: const SizedBox(),
    )));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 9));
    expect(repository.productCalls, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repository.productCalls, 2);
    await tester.pumpWidget(const SizedBox());
  });
}

