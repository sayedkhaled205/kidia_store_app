import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/theme/cms_preview_scroll_behavior.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_block.dart';
import 'package:mobishop_store_app/features/home/presentation/widgets/home_block_renderer.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/preview_focus_frame.dart';

void main() {
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
