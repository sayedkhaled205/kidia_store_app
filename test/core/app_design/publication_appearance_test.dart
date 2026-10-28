import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/core/app_design/app_ui_controls.dart';
import 'package:mobishop_store_app/core/theme/published_message_theme.dart';
import 'package:mobishop_store_app/features/checkout/presentation/checkout_appearance.dart';

void main() {
  test(
    'message overrides keep content/action contrast for light and dark brands',
    () {
      for (final brand in [
        Colors.white,
        Colors.black,
        const Color(0xff4ea999),
      ]) {
        for (final mode in ['soft', 'brand', 'theme']) {
          final base = ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: brand,
            ).copyWith(primary: brand),
          );
          expect(
            identical(
              publishedMessageTheme(base, AppUiControls.defaults),
              base,
            ),
            isTrue,
          );
          final next = publishedMessageTheme(
            base,
            AppUiControls.fromJson({
              'message_style': mode,
              'message_radius': 0,
              'message_inset': 8,
              'message_font_size': 16,
            }),
          ).snackBarTheme;
          final back = next.backgroundColor!.computeLuminance();
          final front = next.contentTextStyle!.color!.computeLuminance();
          final ratio =
              (back > front ? back + .05 : front + .05) /
              (back > front ? front + .05 : back + .05);
          expect(ratio, greaterThanOrEqualTo(4.5));
          expect(next.actionTextColor, next.contentTextStyle!.color);
          expect(next.contentTextStyle!.fontSize, 16);
          expect(next.behavior, SnackBarBehavior.floating);
        }
      }
    },
  );

  testWidgets(
    'live appearance changes keep entered checkout data and validation',
    (tester) async {
      final text = TextEditingController();
      addTearDown(text.dispose);
      final controls = ValueNotifier(AppUiControls.defaults);
      addTearDown(controls.dispose);
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder(
              valueListenable: controls,
              builder: (context, value, _) => AppUiControlsScope(
                controls: value,
                child: Builder(
                  builder: (context) {
                    final appearance = CheckoutAppearance.of(context);
                    final base = InputDecorationThemeData(
                      filled: true,
                      fillColor: Colors.white,
                      border: const OutlineInputBorder(),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.green, width: 2),
                      ),
                      errorBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.red),
                      ),
                    );
                    return Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(inputDecorationTheme: appearance.fields(base)),
                      child: Form(
                        key: form,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: text,
                              validator: (value) =>
                                  value == 'Saved address' ? null : 'Required',
                            ),
                            FilledButton(
                              style: appearance.buttonStyle(),
                              onPressed: () {},
                              child: const Text('Place order'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), 'Saved address');
      for (final values in [
        {
          'checkout_field_radius': 0,
          'checkout_field_padding': 12,
          'checkout_button_height': 44,
          'checkout_button_radius': 0,
          'checkout_button_font_size': 14,
        },
        {
          'checkout_field_radius': 24,
          'checkout_field_padding': 24,
          'checkout_button_height': 64,
          'checkout_button_radius': 32,
          'checkout_button_font_size': 22,
        },
        <String, dynamic>{},
      ]) {
        controls.value = AppUiControls.fromJson(values);
        await tester.pumpAndSettle();
        expect(text.text, 'Saved address');
        expect(form.currentState!.validate(), isTrue);
        final theme = Theme.of(tester.element(find.byType(TextFormField)));
        expect(
          (theme.inputDecorationTheme.errorBorder! as OutlineInputBorder)
              .borderSide
              .color,
          Colors.red,
        );
        expect(
          (theme.inputDecorationTheme.focusedBorder! as OutlineInputBorder)
              .borderSide
              .width,
          2,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );
}
