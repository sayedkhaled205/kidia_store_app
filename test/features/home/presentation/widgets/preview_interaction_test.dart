import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/theme/cms_preview_scroll_behavior.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:mobishop_store_app/features/home/data/models/home_block_model.dart';
import 'package:mobishop_store_app/features/home/presentation/widgets/home_block_renderer.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/preview_focus_frame.dart';

void main() {
  testWidgets('long collections focus at their heading on every selection', (
    tester,
  ) async {
    final keys = [GlobalKey(), GlobalKey()];
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: Column(
              children: [
                const SizedBox(height: 900),
                SizedBox(key: keys[0], height: 3200),
                SizedBox(key: keys[1], height: 1300),
                const SizedBox(height: 800),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final index in [0, 1, 0, 1]) {
      schedulePreviewFocus(
        () => focusPreviewSection(keys[index].currentContext!),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(keys[index])).dy, closeTo(0, 1));
    }
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });

  testWidgets(
    'empty product cards remain selectable repeatedly in the editor',
    (tester) async {
      final scroll = ScrollController();
      final keys = <String, GlobalKey>{};
      final blocks = <HomeBlock>[
        for (var i = 0; i < 4; i++) ...[
          SpacerBlock(id: 'gap-$i', enabled: true, height: 700),
          HomeBlockModel.fromJson({
            'id': 'products-$i',
            'type': i.isEven ? 'product_carousel' : 'product_grid',
            'enabled': true,
            'data': {'title': 'Products $i', 'items': [], 'limit': 'all'},
          }),
        ],
        const SpacerBlock(id: 'end', enabled: true, height: 700),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomScrollView(
              controller: scroll,
              slivers: [
                HomeBlockRenderer(
                  blocks: blocks,
                  onAction: (_) {},
                  keyForBlock: (id) => keys.putIfAbsent(id, GlobalKey.new),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (AppConfig.isCmsPreview) {
        // Jump forward, backward, then repeat an earlier selection after manual
        // scrolling. Every empty carousel/grid needs real, stable geometry.
        for (final i in [3, 0, 2, 1, 3, 0]) {
          final key = keys['products-$i']!;
          expect(key.currentContext, isNotNull);
          schedulePreviewFocus(() => focusPreviewSection(key.currentContext!));
          await tester.pumpAndSettle();
          final top = tester.getTopLeft(find.byKey(key)).dy;
          expect(top, closeTo(0, 2));
          scroll.jumpTo(0);
          await tester.pumpAndSettle();
        }
      } else {
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(find.textContaining('No products are available'), findsNothing);
        expect(keys.keys.where((id) => id.startsWith('products-')), isEmpty);
      }
      await tester.pumpWidget(const SizedBox());
      scroll.dispose();
    },
  );

  testWidgets('idle preview starts selection without a carousel tick', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, false);
    var calls = 0;
    schedulePreviewFocus(() => calls++);
    expect(tester.binding.hasScheduledFrame, true);
    await tester.pump();
    expect(calls, 1);
    expect(tester.binding.hasScheduledFrame, false);
  });

  testWidgets('desktop mouse can drag the phone preview vertically', (
    tester,
  ) async {
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        scrollBehavior: const CmsPreviewScrollBehavior(),
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: const [SizedBox(height: 4000)],
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      const Offset(200, 450),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(0, -180));
    await tester.pump();
    expect(scroll.offset, greaterThan(100));
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });

  testWidgets('preview mounts distant section geometry before a selection', (
    tester,
  ) async {
    final scroll = ScrollController();
    final keys = <String, GlobalKey>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            controller: scroll,
            slivers: [
              HomeBlockRenderer(
                blocks: List.generate(
                  12,
                  (i) =>
                      SpacerBlock(id: 'section-$i', enabled: true, height: 300),
                ),
                onAction: (_) {},
                keyForBlock: (id) => keys.putIfAbsent(id, GlobalKey.new),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    if (AppConfig.isCmsPreview) {
      final target = keys['section-10']!.currentContext!;
      schedulePreviewFocus(
        () => Scrollable.ensureVisible(target, alignment: .18),
      );
      await tester.pump();
      await tester.pump();
      expect(scroll.offset, greaterThan(2500));
    } else {
      expect(keys['section-10']?.currentContext, isNull);
    }
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });
}
