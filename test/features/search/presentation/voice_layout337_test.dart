import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/search/application/voice_search_engine.dart';
import 'package:mobishop_store_app/features/search/presentation/voice_search_dialog.dart';

class UnavailableEngine implements VoiceSearchEngine {
  int cancelled = 0;
  @override Future<bool> start({required String language, required void Function(String) onWords, required void Function() onError, required void Function() onDone}) async => false;
  @override Future<void> cancel() async { cancelled++; }
  @override Future<void> stop() async {}
}

void main() {
  for (final config in [(1.0, 0.0), (1.0, 260.0), (1.8, 0.0), (1.8, 260.0)]) {
    testWidgets('voice fallback remains usable at 320x568 scale ${config.$1} keyboard ${config.$2}', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final engine = UnavailableEngine();
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'), supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(config.$1), viewInsets: EdgeInsets.only(bottom: config.$2)), child: child!),
        home: Scaffold(body: Builder(builder: (context) => TextButton(onPressed: () => showDialog<String>(context: context, builder: (_) => VoiceSearchDialog(engine: engine)), child: const Text('Open')))),
      ));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byKey(const Key('voice-search-query')), 'حذاء');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.widget<FilledButton>(find.byKey(const Key('voice-search-submit'))).onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('voice-search-cancel')));
      await tester.pumpAndSettle();
      expect(engine.cancelled, 1);
    });
  }
}
