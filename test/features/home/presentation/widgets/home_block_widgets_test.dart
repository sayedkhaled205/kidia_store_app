import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';
import 'package:kidia_store_app/features/home/presentation/widgets/home_block_widgets.dart';

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
