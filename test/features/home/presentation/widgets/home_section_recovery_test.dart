import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:mobishop_store_app/features/home/presentation/widgets/home_block_renderer.dart';

void main() {
  testWidgets(
    'a failed live section leaves the saved banner visible and can request retry',
    (tester) async {
      HomeAction? action;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  HomeBlockRenderer(
                    blocks: [
                      const PromoStripBlock(
                        id: 'saved-banner',
                        enabled: true,
                        text: 'Our saved store banner',
                        backgroundColor: '#FFFFFF',
                        textColor: '#111111',
                        action: HomeAction(type: 'cart', value: ''),
                      ),
                      CatalogUnavailableBlock(
                        const SpacerBlock(
                          id: 'live-products',
                          enabled: true,
                          height: 40,
                        ),
                      ),
                    ],
                    onAction: (value) => action = value,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Our saved store banner'), findsOneWidget);
      expect(find.text('Reload this section'), findsOneWidget);
      await tester.tap(find.text('Reload this section'));
      expect(action?.type, 'retry_home');
    },
  );
}
