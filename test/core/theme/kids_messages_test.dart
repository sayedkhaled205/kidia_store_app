import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/theme/mobishop_theme.dart';
import 'package:mobishop_store_app/core/theme/preview_identity_theme.dart';

void main() {
  testWidgets(
    'Kids messages and actions follow published color in both languages',
    (tester) async {
      for (final direction in TextDirection.values) {
        for (final color in ['#4ea999', '#163c35']) {
          final theme = applicationIdentityTheme(MobiShopTheme.light, {
            'primary_color': color,
          });
          final key = GlobalKey<ScaffoldMessengerState>();
          await tester.pumpWidget(
            MaterialApp(
              theme: theme,
              scaffoldMessengerKey: key,
              home: Directionality(
                textDirection: direction,
                child: const Scaffold(),
              ),
            ),
          );
          final message = direction == TextDirection.rtl
              ? 'تم تسجيل الخروج.'
              : 'You have been signed out.';
          key.currentState!.showSnackBar(
            SnackBar(
              content: Text(message),
              action: SnackBarAction(label: 'Undo', onPressed: () {}),
              showCloseIcon: true,
            ),
          );
          await tester.pumpAndSettle();
          final contentContext = tester.element(find.text(message));
          final surface = tester.widget<Material>(
            find
                .ancestor(
                  of: find.text(message),
                  matching: find.byType(Material),
                )
                .first,
          );
          final foreground = DefaultTextStyle.of(contentContext).style.color!;
          expect(surface.color, theme.colorScheme.primary);
          final luminances = [
            foreground.computeLuminance(),
            surface.color!.computeLuminance(),
          ]..sort();
          expect(
            (luminances.last + 0.05) / (luminances.first + 0.05),
            greaterThanOrEqualTo(4.5),
          );
          expect(theme.snackBarTheme.actionTextColor, foreground);
          expect(theme.snackBarTheme.closeIconColor, foreground);
          expect(
            previewIdentityTheme(MobiShopTheme.light, {
              'primary_color': color,
            }).snackBarTheme,
            theme.snackBarTheme,
          );
          key.currentState!.removeCurrentSnackBar();
          await tester.pumpAndSettle();
        }
      }
    },
  );

  test('Unbranded applications keep their existing message appearance', () {
    final base = MobiShopTheme.light;
    expect(
      applicationIdentityTheme(base, {'app_name': 'Example'}).snackBarTheme,
      base.snackBarTheme,
    );
  });
}
