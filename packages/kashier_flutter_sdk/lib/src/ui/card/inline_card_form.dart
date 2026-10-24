import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../models/kashier_language.dart';
import '../../../models/kashier_mode.dart';
import '../../../models/kashier_payment_error.dart';
import '../../kashier_api.dart';
import '../../kashier_sdk.dart';
import '../../models/kashier_card.dart';
import '../../payment_handler/card/kashier_card_handler.dart';
import '../../validation/card_validator.dart';
import '../kashier_payment_overlay.dart';
import '../kashier_payment_provider.dart';
import 'card_number_formatter.dart';
import 'expiry_formatter.dart';
import 'three_ds_webview_sheet.dart';

/// The merchant can validate/submit the SDK form, never read its card fields.
/// PAN/CVV stay in this ephemeral SDK widget and go directly to Kashier.
class KashierInlineCardController {
  _KashierInlineCardFormState? _state;

  bool validate() => _state?._formKey.currentState?.validate() ?? false;
  void clear() => _state?._clear();

  Future<void> pay({
    required String sessionId,
    required KashierMode mode,
    required KashierLanguage language,
    required String expectedAmount,
    required String expectedCurrency,
    required bool Function() canContinue,
  }) async {
    final state = _state;
    if (state == null || !state.mounted || state._paying || !validate()) {
      throw StateError('Card form is not ready.');
    }
    await state._pay(
      sessionId: sessionId,
      mode: mode,
      language: language,
      expectedAmount: expectedAmount,
      expectedCurrency: expectedCurrency,
      canContinue: canContinue,
    );
  }
}

/// Exact decimal comparison without binary floating-point rounding.
bool kashierInlineAmountMatches(String expected, String actual) {
  String? normalize(String value) {
    if (!RegExp(r'^(0|[1-9][0-9]{0,11})(\.[0-9]{1,6})?$').hasMatch(value)) {
      return null;
    }
    final parts = value.split('.');
    final fraction =
        parts.length == 1 ? '' : parts[1].replaceFirst(RegExp(r'0+$'), '');
    return '${parts[0]}.$fraction';
  }

  final left = normalize(expected);
  return left != null && left == normalize(actual);
}

class KashierInlineCardForm extends StatefulWidget {
  const KashierInlineCardForm(
      {required this.controller, this.enabled = true, super.key});
  final KashierInlineCardController controller;
  final bool enabled;

  @override
  State<KashierInlineCardForm> createState() => _KashierInlineCardFormState();
}

class _KashierInlineCardFormState extends State<KashierInlineCardForm> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  final _name = TextEditingController();
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override
  void didUpdateWidget(KashierInlineCardForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller._state = null;
      widget.controller._state = this;
      _clear();
    }
  }

  void _clear() {
    _number.clear();
    _expiry.clear();
    _cvv.clear();
    _name.clear();
  }

  @override
  void dispose() {
    widget.controller._state = null;
    _clear();
    _number.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _pay({
    required String sessionId,
    required KashierMode mode,
    required KashierLanguage language,
    required String expectedAmount,
    required String expectedCurrency,
    required bool Function() canContinue,
  }) async {
    _paying = true;
    final parts = _expiry.text.split('/');
    final input = KashierCardInput(
      cardNumber: _number.text.replaceAll(RegExp(r'\D'), ''),
      nameOnCard: _name.text.trim(),
      expiryMonth: parts[0],
      expiryYear: parts[1],
      cvv: _cvv.text,
      saveCard: false,
    );
    KashierSDK.initialize(mode: mode, language: language);
    final api = KashierApi(mode: mode);
    final handler = KashierCardHandler(api: api);
    final finished = Completer<KashierErrorCode?>();
    final provider = KashierPaymentProviderState.instance;
    var showingChallenge = false;
    void finish([KashierErrorCode? error]) {
      if (!finished.isCompleted) finished.complete(error);
    }

    try {
      final session = await api.getSession(sessionId);
      if (!mounted ||
          !canContinue() ||
          session.sessionId != sessionId ||
          session.currency != expectedCurrency ||
          !kashierInlineAmountMatches(
              expectedAmount, session.rawAmount.toString()) ||
          (session.allowedMethods.isNotEmpty &&
              !session.allowedMethods.contains('card')) ||
          session.saveCard == 'forced') {
        throw StateError('Payment session no longer matches checkout.');
      }
      await handler.startPayment(
        session: session,
        onSuccess: (_) => finish(),
        onFailure: (error) => finish(error.code),
        onPending: (_) => finish(),
      );
      if (!mounted || !canContinue()) throw StateError('Checkout changed.');
      // Clear the UI as the single explicit payment request is dispatched.
      // Nothing is serialized to merchant requests, preferences or analytics.
      _clear();
      final response = await handler.payWithNewCard(input);
      if (response.isSuccess) {
        handler.completeWithSuccess(response);
      } else if (response.needs3DS && provider != null && mounted) {
        showingChallenge = true;
        void cancel() => handler.completeWithFailure(
              KashierPaymentError.fromCode(KashierErrorCode.userCancelled),
            );
        provider.showPaymentSheet(KashierPaymentOverlay(
          fullScreen: true,
          onDismiss: cancel,
          child: ThreeDSWebViewSheet(
            redirectUrl: response.redirectUrl!,
            merchantRedirect: session.merchantRedirect,
            onComplete: handler.complete3DS,
            onReconcileRequested: handler.start3DSReconcile,
            onCancel: cancel,
          ),
        ));
      } else {
        finish(KashierErrorCode.authenticationFailed);
      }
      final error = await finished.future;
      if (error != null) throw StateError('Native payment: ${error.name}');
    } finally {
      if (showingChallenge) provider?.dismissPaymentSheet();
      handler.dispose();
      api.dispose();
      _paying = false;
      if (mounted) _clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String copy(String en, String arabic) => ar ? arabic : en;
    InputDecoration decoration(String label, {IconData? icon}) =>
        InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 19),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xffd9d9d9))),
          suffixIcon: icon == null ? null : Icon(icon, size: 21),
        );
    Widget field(
            {required String id,
            required TextEditingController controller,
            required String label,
            required String? Function(String?) validator,
            List<TextInputFormatter>? formatters,
            bool secret = false,
            TextInputType keyboard = TextInputType.number,
            IconData? icon}) =>
        TextFormField(
          key: ValueKey('inline-card-$id'),
          controller: controller,
          enabled: widget.enabled && !_paying,
          keyboardType: keyboard,
          textDirection: TextDirection.ltr,
          textInputAction:
              id == 'name' ? TextInputAction.done : TextInputAction.next,
          enableSuggestions: false,
          autocorrect: false,
          obscureText: secret,
          enableIMEPersonalizedLearning: false,
          inputFormatters: formatters,
          validator: validator,
          style: const TextStyle(fontSize: 16),
          decoration: decoration(label, icon: icon),
        );
    return Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        field(
            id: 'number',
            controller: _number,
            label: copy('Card number', 'رقم البطاقة'),
            icon: Icons.lock_outline,
            formatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
              CardNumberFormatter()
            ],
            validator: (v) => CardValidator.validateCardNumber(
                    (v ?? '').replaceAll(' ', ''))
                ? null
                : copy('Enter a valid card number', 'أدخل رقم بطاقة صحيحًا')),
        const SizedBox(height: 12),
        field(
            id: 'expiry',
            controller: _expiry,
            label:
                copy('Expiration date (MM / YY)', 'تاريخ الانتهاء (MM / YY)'),
            formatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d/]')),
              ExpiryFormatter()
            ],
            validator: (v) {
              final p = (v ?? '').split('/');
              return p.length == 2 && CardValidator.validateExpiry(p[0], p[1])
                  ? null
                  : copy('Enter a valid expiration date',
                      'أدخل تاريخ انتهاء صحيحًا');
            }),
        const SizedBox(height: 12),
        field(
            id: 'cvv',
            controller: _cvv,
            label: copy('Security code', 'رمز الأمان'),
            secret: true,
            icon: Icons.help_outline,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4)
            ],
            validator: (v) => CardValidator.validateCvv(v ?? '',
                    CardValidator.detectBrand(_number.text.replaceAll(' ', '')))
                ? null
                : copy(
                    'Enter a valid security code', 'أدخل رمز الأمان الصحيح')),
        const SizedBox(height: 12),
        field(
            id: 'name',
            controller: _name,
            keyboard: TextInputType.name,
            label: copy('Name on card', 'الاسم على البطاقة'),
            formatters: [LengthLimitingTextInputFormatter(50)],
            validator: (v) => CardValidator.validateName(v ?? '')
                ? null
                : copy('Enter the name on your card',
                    'أدخل الاسم الموجود على البطاقة')),
      ]),
    );
  }
}
