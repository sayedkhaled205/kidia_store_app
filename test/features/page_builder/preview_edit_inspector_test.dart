import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/widgets/preview_edit_region.dart';

void main() {
  testWidgets(
    'small header icons keep their center tap, even at viewport edges',
    (tester) async {
      if (!AppConfig.isCmsPreview) return;
      for (final alignment in [
        Alignment.topLeft,
        Alignment.topRight,
        Alignment.bottomLeft,
        Alignment.bottomRight,
        Alignment.center,
      ]) {
        for (final size in [28.0, 40.0, 50.0]) {
          var taps = 0;
          final edits = <PreviewEditSelection>[];
          await tester.pumpWidget(
            MaterialApp(
              home: PreviewEditInspector(
                key: UniqueKey(),
                onEdit: edits.add,
                child: Align(
                  alignment: alignment,
                  child: PreviewEditRegion(
                    page: 'product',
                    target: 'header',
                    item: 'back',
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => taps++,
                        child: const Icon(Icons.arrow_back),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          final center = tester.getCenter(find.byIcon(Icons.arrow_back));
          await mouse.addPointer(location: center);
          await mouse.moveTo(center);
          await tester.pump();
          final button = find.byKey(const Key('preview-edit-button'));
          expect(tester.getRect(button).contains(center), isFalse);
          await mouse.down(center);
          await mouse.up();
          await tester.pump();
          expect(taps, 1);
          expect(edits, isEmpty);
          final corner = tester.getCenter(button);
          await mouse.moveTo(corner);
          await tester.pump();
          await mouse.down(corner);
          await mouse.up();
          await tester.pump();
          expect(edits.single.item, 'back');
          expect(taps, 1);
          await mouse.removePointer();
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'fast movement from a pencil selects the next section immediately',
    (tester) async {
      if (!AppConfig.isCmsPreview) return;
      final edits = <PreviewEditSelection>[];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              PreviewEditInspector(onEdit: edits.add, child: child!),
          home: Scaffold(
            body: Column(
              children: [
                for (final id in ['first', 'second', 'third'])
                  PreviewEditRegion(
                    page: 'home',
                    target: id,
                    child: SizedBox(
                      width: 250,
                      height: 150,
                      child: Center(child: Text(id)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      for (final id in ['first', 'second', 'third', 'first']) {
        await mouse.moveTo(tester.getCenter(find.text(id)));
        await tester.pump();
        final button = tester.getCenter(
          find.byKey(const Key('preview-edit-button')),
        );
        await mouse.moveTo(button);
        await tester.pump(const Duration(seconds: 1));
        await mouse.down(button);
        await mouse.up();
        await tester.pump();
        expect(edits.last.target, id);
        expect(tester.takeException(), isNull);
      }
      await mouse.removePointer();
    },
  );

  testWidgets(
    'hover outlines exact region; center taps operate, corner edits',
    (tester) async {
      var taps = 0;
      final edits = <PreviewEditSelection>[];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) =>
              PreviewEditInspector(onEdit: edits.add, child: child!),
          home: Scaffold(
            body: Center(
              child: PreviewEditRegion(
                page: 'home',
                target: 'new-arrivals-19',
                child: SizedBox(
                  width: 250,
                  height: 160,
                  child: GestureDetector(
                    onTap: () => taps++,
                    behavior: HitTestBehavior.opaque,
                    child: const Center(child: Text('Open product')),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      if (!AppConfig.isCmsPreview) {
        expect(find.byKey(const Key('preview-edit-button')), findsNothing);
        return;
      }
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(find.text('Open product')));
      await tester.pump();
      expect(find.byKey(const Key('preview-edit-outline')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('preview-edit-outline'))),
        const Size(250, 160),
      );
      await mouse.down(tester.getCenter(find.text('Open product')));
      await mouse.up();
      await tester.pump();
      expect(taps, 1);
      expect(edits, isEmpty);
      final button = tester.getCenter(
        find.byKey(const Key('preview-edit-button')),
      );
      await mouse.moveTo(button);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
      await mouse.down(button);
      await mouse.up();
      await tester.pump();
      expect(taps, 1);
      expect(edits.single.page, 'home');
      expect(edits.single.target, 'new-arrivals-19');
      await mouse.removePointer();
      await tester.pump();
      expect(find.byKey(const Key('preview-edit-outline')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'nested header item selects its own controls and native rendering is unchanged',
    (tester) async {
      final edits = <PreviewEditSelection>[];
      await tester.pumpWidget(
        MaterialApp(
          home: PreviewEditInspector(
            onEdit: edits.add,
            child: PreviewEditScope(
              page: 'category',
              child: Scaffold(
                body: Center(
                  child: PreviewEditRegion(
                    target: 'header',
                    child: SizedBox(
                      width: 300,
                      height: 70,
                      child: Center(
                        child: PreviewEditRegion(
                          target: 'header',
                          item: 'cart',
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.shopping_bag_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(
        tester.getCenter(find.byIcon(Icons.shopping_bag_outlined)),
      );
      await tester.pump();
      if (!AppConfig.isCmsPreview) {
        expect(find.byKey(const Key('preview-edit-outline')), findsNothing);
      } else {
        expect(
          tester.getSize(find.byKey(const Key('preview-edit-outline'))),
          const Size(50, 50),
        );
        final button = tester.getCenter(
          find.byKey(const Key('preview-edit-button')),
        );
        await mouse.moveTo(button);
        await tester.pump();
        await mouse.down(button);
        await mouse.up();
        await tester.pump();
        expect(edits.single.page, 'category');
        expect(edits.single.item, 'cart');
      }
      await mouse.removePointer();
    },
  );

  testWidgets(
    'long section has visible corner; scrolling updates hover and route removal is safe',
    (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: PreviewEditInspector(
            child: Scaffold(
              body: ListView(
                controller: scroll,
                children: [
                  PreviewEditRegion(
                    page: 'home',
                    target: 'long-feed',
                    child: Container(height: 1500, color: Colors.white),
                  ),
                  PreviewEditRegion(
                    page: 'home',
                    target: 'second-feed',
                    child: Container(height: 700, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(const Offset(200, 200));
      await tester.pump();
      if (AppConfig.isCmsPreview) {
        expect(
          tester.getRect(find.byKey(const Key('preview-edit-outline'))).bottom,
          600,
        );
        scroll.jumpTo(1550);
        await tester.pump();
        await tester.pump();
        expect(
          tester.getRect(find.byKey(const Key('preview-edit-outline'))).top,
          0,
        );
      }
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await mouse.removePointer();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
