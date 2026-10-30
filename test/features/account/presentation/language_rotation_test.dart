import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobishop_store_app/features/account/presentation/app_language_tile.dart';

void main() {
  for (final size in [const Size(390, 844), const Size(768, 1024)]) {
    testWidgets('language choices survive rotation $size', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: AppLanguageTile())),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-language')));
      await tester.pumpAndSettle();
      tester.view.physicalSize = Size(size.height, size.width);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('app-language-en')));
      await tester.tap(find.byKey(const Key('app-language-en')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-language-en')), findsNothing);
    });
  }
}

