import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kashier_flutter_sdk/kashier_flutter_sdk.dart';
import 'package:kashier_flutter_sdk/src/ui/card/expiry_formatter.dart';
import 'package:kashier_flutter_sdk/src/ui/card/card_form_sheet.dart';
import 'package:kashier_flutter_sdk/src/kashier_api.dart';
import 'package:kashier_flutter_sdk/src/models/kashier_session.dart';
import 'package:kashier_flutter_sdk/src/payment_handler/card/kashier_card_handler.dart';
import 'package:http/testing.dart';

void main() {
  testWidgets(
      'recovery sheet keeps slash visible and mask aligned while typing',
      (tester) async {
    final client = MockClient(
        (_) async => throw StateError('No payment request expected'));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CardFormSheet(
      session: KashierSession.fromJson(
          {'amount': 1, 'currency': 'EGP'}, 'synthetic-session'),
      cardHandler: KashierCardHandler(
          api: KashierApi(mode: KashierMode.test, client: client)),
      onBack: () {},
      onPaymentResponse: (_) {},
    ))));
    final field = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.hintText == 'MM/YY');
    await tester.enterText(field, '1');
    await tester.pump();
    final mask = find.byKey(const Key('expiry-remaining-mask'));
    final editable =
        find.descendant(of: field, matching: find.byType(EditableText));
    expect(tester.widget<Text>(mask).textSpan!.toPlainText(), '1M/YY');
    expect(
        tester.getTopLeft(mask).dx, closeTo(tester.getTopLeft(editable).dx, 1));
    expect(
        tester.getTopLeft(mask).dy, closeTo(tester.getTopLeft(editable).dy, 1));
    expect(tester.widget<EditableText>(editable).controller.text, '1');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    client.close();
  });
  testWidgets(
      'expiry slash stays visible from first digit in Arabic without altering input',
      (tester) async {
    final controller = KashierInlineCardController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Directionality(
      textDirection: TextDirection.rtl,
      child: KashierInlineCardForm(controller: controller),
    ))));
    final field = find.byKey(const Key('inline-card-expiry'));
    final editable =
        find.descendant(of: field, matching: find.byType(EditableText));
    final mask = find.byKey(const Key('expiry-remaining-mask'));
    for (final entry in {
      '1': '1M/YY',
      '12': '12/YY',
      '123': '12/3Y',
      '1239': null,
      '': null
    }.entries) {
      await tester.enterText(field, entry.key);
      await tester.pump();
      final widget = tester.widget<EditableText>(editable);
      expect(widget.textDirection, TextDirection.ltr);
      expect(
          widget.controller.text,
          entry.key.length > 2
              ? '${entry.key.substring(0, 2)}/${entry.key.substring(2)}'
              : entry.key);
      if (entry.value == null) {
        expect(mask, findsNothing);
      } else {
        expect(tester.widget<Text>(mask).textSpan!.toPlainText(), entry.value);
        expect(tester.getTopLeft(mask).dx,
            closeTo(tester.getTopLeft(editable).dx, 1));
        expect(tester.getTopLeft(mask).dy,
            closeTo(tester.getTopLeft(editable).dy, 1));
      }
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('expiry formatter keeps paste, delete and cursor semantics', () {
    final formatter = ExpiryFormatter();
    TextEditingValue format(String text, [int? cursor]) =>
        formatter.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
              text: text,
              selection:
                  TextSelection.collapsed(offset: cursor ?? text.length)),
        );
    expect(format('1').text, '1');
    expect(format('12').text, '12');
    expect(format('12 / 39').text, '12/39');
    expect(format('12/3').text, '12/3');
    expect(format('1239', 1).selection.baseOffset, 1);
    expect(format('12/39', 4).selection.baseOffset, 4);
    expect(format('').text, isEmpty);
  });
}

