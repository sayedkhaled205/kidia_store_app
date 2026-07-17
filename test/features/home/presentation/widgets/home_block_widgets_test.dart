import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';
import 'package:kidia_store_app/features/home/presentation/widgets/home_block_widgets.dart';
import 'package:kidia_store_app/features/home/presentation/widgets/home_block_frame.dart';

void main() {
  Future<void> pumpBlock(WidgetTester tester, Widget block) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: block)),
      ),
    );
  }

  testWidgets('promo strip applies CMS colors and dispatches its action', (
    WidgetTester tester,
  ) async {
    HomeAction? receivedAction;

    await pumpBlock(
      tester,
      PromoStripBlockWidget(
        block: const PromoStripBlock(
          id: 'promo-1',
          enabled: true,
          text: 'شحن مجاني',
          backgroundColor: '#123456',
          textColor: '#fff',
          action: HomeAction(type: 'collection', value: 'summer'),
        ),
        onAction: (HomeAction action) {
          receivedAction = action;
        },
      ),
    );

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Material && widget.color == const Color(0xFF123456),
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('شحن مجاني'));
    await tester.pump();

    expect(receivedAction?.type, 'collection');
    expect(receivedAction?.value, 'summer');
  });

  testWidgets('app header renders configured actions and dispatches them', (
    WidgetTester tester,
  ) async {
    final List<String> actions = <String>[];
    await pumpBlock(
      tester,
      AppHeaderBlockWidget(
        block: const AppHeaderBlock(
          id: 'header-1',
          enabled: true,
          logoUrl: null,
          title: 'Kidia',
          subtitle: 'Kids fashion',
          layout: 'center',
          height: 72,
          logoHeight: 40,
          showSearch: true,
          showCart: true,
          showAccount: true,
          titleColor: '#123456',
          iconColor: '#654321',
        ),
        onAction: (HomeAction action) => actions.add(action.type),
      ),
    );

    expect(find.text('Kidia'), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.search_rounded));
    await tester.tap(find.byIcon(Icons.shopping_bag_outlined));
    await tester.tap(find.byIcon(Icons.person_outline_rounded));
    expect(actions, <String>['search', 'cart', 'account']);
  });

  testWidgets('shared block frame adapts spacing to the screen width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const SpacerBlock block = SpacerBlock(
      id: 'space-1',
      enabled: true,
      height: 20,
      presentation: HomeBlockPresentation(
        marginTop: 8,
        marginBottom: 12,
        marginHorizontal: 10,
        paddingVertical: 6,
        paddingHorizontal: 14,
        backgroundColor: '#FAFAFA',
        borderRadius: 18,
      ),
    );
    await pumpBlock(
      tester,
      const HomeBlockFrame(block: block, child: SizedBox(height: 20)),
    );

    final Padding frame = tester.widget<Padding>(
      find.byKey(const Key('home-block-frame-space-1')),
    );
    expect(
      frame.padding.resolve(TextDirection.ltr),
      const EdgeInsets.fromLTRB(10, 8, 10, 12),
    );
    expect(find.byType(HomeResponsiveScope), findsOneWidget);
  });

  testWidgets('video banner exposes an accessible playable fallback action', (
    WidgetTester tester,
  ) async {
    HomeAction? receivedAction;
    final SemanticsHandle semantics = tester.ensureSemantics();

    await pumpBlock(
      tester,
      VideoBannerBlockWidget(
        block: const VideoBannerBlock(
          id: 'video-1',
          enabled: true,
          videoUrl: 'https://example.com/lookbook.mp4',
          posterUrl: null,
          aspectRatio: 1.8,
          autoPlay: false,
          muted: true,
          loop: false,
          action: null,
        ),
        onAction: (HomeAction action) {
          receivedAction = action;
        },
      ),
    );

    expect(find.bySemanticsLabel('تشغيل الفيديو'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();

    expect(receivedAction?.type, 'external');
    expect(receivedAction?.value, 'https://example.com/lookbook.mp4');

    semantics.dispose();
  });

  testWidgets('coupon banner copies its code and confirms the action', (
    WidgetTester tester,
  ) async {
    final List<MethodCall> platformCalls = <MethodCall>[];
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    messenger.setMockMethodCallHandler(SystemChannels.platform, (
      MethodCall methodCall,
    ) async {
      platformCalls.add(methodCall);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await pumpBlock(
      tester,
      const CouponBannerBlockWidget(
        block: CouponBannerBlock(
          id: 'coupon-1',
          enabled: true,
          title: 'خصم خاص',
          description: 'استخدمي الكود عند الدفع',
          couponCode: 'KIDIA20',
          imageUrl: null,
        ),
      ),
    );

    await tester.tap(find.text('KIDIA20'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final MethodCall clipboardCall = platformCalls.singleWhere(
      (MethodCall call) => call.method == 'Clipboard.setData',
    );
    expect(
      (clipboardCall.arguments as Map<Object?, Object?>)['text'],
      'KIDIA20',
    );
    expect(find.text('تم نسخ كود الخصم'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('text and divider blocks render their CMS style values', (
    WidgetTester tester,
  ) async {
    await pumpBlock(
      tester,
      Column(
        children: const [
          TextBlockWidget(
            block: TextBlock(
              id: 'text-1',
              enabled: true,
              title: 'عنوان',
              content: 'نص القسم',
              alignment: HomeTextAlignment.center,
              backgroundColor: '#fafafa',
              textColor: '#112233',
            ),
          ),
          DividerBlockWidget(
            block: DividerBlock(
              id: 'divider-1',
              enabled: true,
              color: '#abcdef',
              thickness: 3,
              margin: 12,
            ),
          ),
        ],
      ),
    );

    final Text title = tester.widget<Text>(find.text('عنوان'));
    expect(title.textAlign, TextAlign.center);
    expect(title.style?.color, const Color(0xFF112233));
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is ColoredBox && widget.color == const Color(0xFFABCDEF),
      ),
      findsOneWidget,
    );
  });

  testWidgets('countdown cancels its timer when removed', (
    WidgetTester tester,
  ) async {
    await pumpBlock(
      tester,
      CountdownBlockWidget(
        block: CountdownBlock(
          id: 'countdown-1',
          enabled: true,
          title: 'العرض ينتهي خلال',
          endsAt: DateTime.now().toUtc().add(const Duration(minutes: 5)),
          expiredText: 'انتهى العرض',
        ),
      ),
    );

    expect(find.text('العرض ينتهي خلال'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));

    expect(tester.takeException(), isNull);
  });
}
