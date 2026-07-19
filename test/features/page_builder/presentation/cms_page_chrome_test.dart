import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';

void main() {
  testWidgets(
    'collapses on every scrolled CMS page and restores only at the top',
    (WidgetTester tester) async {
      await _pumpPage(tester, layout: _layout(page: 'product'));

      expect(_appBar(tester).compact, isFalse);

      await tester.drag(
        find.byKey(const Key('cms-page-scroll')),
        const Offset(0, -240),
      );
      await tester.pump();

      expect(_appBar(tester).compact, isTrue);

      await tester.drag(
        find.byKey(const Key('cms-page-scroll')),
        const Offset(0, 600),
      );
      await tester.pumpAndSettle();

      expect(_appBar(tester).compact, isFalse);
    },
  );

  testWidgets('stays regular when collapsed header is Off', (
    WidgetTester tester,
  ) async {
    await _pumpPage(
      tester,
      layout: _layout(collapseOnScroll: false),
    );

    await tester.drag(
      find.byKey(const Key('cms-page-scroll')),
      const Offset(0, -240),
    );
    await tester.pump();

    expect(_appBar(tester).compact, isFalse);
  });

  testWidgets('maps the five transition choices to mobile animations', (
    WidgetTester tester,
  ) async {
    const Map<String, Type> expectedRoots = <String, Type>{
      'fade': FadeTransition,
      'slide': SlideTransition,
      'fade_slide': FadeTransition,
      'scale': FadeTransition,
    };

    for (final MapEntry<String, Type> entry in expectedRoots.entries) {
      await _pumpPage(
        tester,
        layout: _layout(transition: entry.key),
      );
      final AnimatedSwitcher switcher = tester.widget<AnimatedSwitcher>(
        find.byKey(const Key('cms-page-app-bar-transition')),
      );
      final Widget child = switcher.transitionBuilder(
        const SizedBox(),
        const AlwaysStoppedAnimation<double>(1),
      );

      expect(child.runtimeType, entry.value, reason: entry.key);
      if (entry.key == 'fade_slide') {
        expect((child as FadeTransition).child, isA<SlideTransition>());
      }
      if (entry.key == 'scale') {
        expect((child as FadeTransition).child, isA<ScaleTransition>());
      }
    }

    await _pumpPage(tester, layout: _layout(transition: 'instant'));
    final AnimatedSwitcher instantSwitcher = tester.widget<AnimatedSwitcher>(
      find.byKey(const Key('cms-page-app-bar-transition')),
    );
    expect(instantSwitcher.duration, Duration.zero);
    const Widget instantChild = SizedBox();
    expect(
      instantSwitcher.transitionBuilder(
        instantChild,
        const AlwaysStoppedAnimation<double>(1),
      ),
      same(instantChild),
    );
  });

  testWidgets('maps Fast, Medium and Slow to mobile durations', (
    WidgetTester tester,
  ) async {
    const Map<String, Duration> expected = <String, Duration>{
      'fast': Duration(milliseconds: 160),
      'medium': Duration(milliseconds: 260),
      'slow': Duration(milliseconds: 420),
    };

    for (final MapEntry<String, Duration> entry in expected.entries) {
      await _pumpPage(tester, layout: _layout(speed: entry.key));
      final AnimatedSwitcher switcher = tester.widget<AnimatedSwitcher>(
        find.byKey(const Key('cms-page-app-bar-transition')),
      );
      expect(switcher.duration, entry.value, reason: entry.key);
    }
  });
}

CmsPageAppBar _appBar(WidgetTester tester) => tester.widget<CmsPageAppBar>(
  find.byType(CmsPageAppBar),
);

Future<void> _pumpPage(
  WidgetTester tester, {
  required CmsPageLayout layout,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: CmsPageScaffold(
        layout: layout,
        defaultTitle: 'Products',
        body: ListView.builder(
          key: const Key('cms-page-scroll'),
          itemExtent: 72,
          itemCount: 40,
          itemBuilder: (BuildContext context, int index) => Text('Item $index'),
        ),
      ),
    ),
  );
}

CmsPageLayout _layout({
  String page = 'catalog',
  bool collapseOnScroll = true,
  String transition = 'fade_slide',
  String speed = 'medium',
}) {
  const Map<String, dynamic> regularLayout = <String, dynamic>{
    'rows': <Map<String, dynamic>>[
      <String, dynamic>{
        'columns': <Map<String, dynamic>>[
          <String, dynamic>{
            'width': 100,
            'align': 'center',
            'items': <String>['title'],
          },
        ],
      },
    ],
  };
  const Map<String, dynamic> compactLayout = <String, dynamic>{
    'rows': <Map<String, dynamic>>[
      <String, dynamic>{
        'columns': <Map<String, dynamic>>[
          <String, dynamic>{
            'width': 100,
            'align': 'center',
            'items': <String>['title'],
          },
        ],
      },
    ],
  };

  return CmsPageLayout(
    page: page,
    header: CmsPageComponent(
      id: 'header',
      type: 'app_header',
      enabled: true,
      settings: <String, dynamic>{
        'collapse_on_scroll': collapseOnScroll,
        'collapse_transition': transition,
        'collapse_speed': speed,
        'layout_json': regularLayout,
        'compact_layout_json': compactLayout,
        'height': 80,
        'compact_height': 52,
      },
    ),
    elements: const <CmsPageComponent>[],
    footer: const CmsPageComponent(
      id: 'footer',
      type: 'app_footer',
      enabled: false,
      settings: <String, dynamic>{},
    ),
  );
}
