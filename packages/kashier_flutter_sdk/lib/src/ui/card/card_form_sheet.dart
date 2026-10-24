import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../kashier_sdk.dart';
import '../../../models/kashier_mode.dart';

import '../../../models/kashier_payment_error.dart';
import '../../models/card_payment_response.dart';
import '../../models/kashier_card.dart';
import '../../models/kashier_session.dart';
import '../../payment_handler/card/kashier_card_handler.dart';
import '../../validation/card_validator.dart';
import '../kashier_branding.dart';
import '../kashier_colors.dart';
import '../kashier_drag_handle.dart';
import '../kashier_localizations.dart';
import 'card_brand_icon.dart';
import 'card_number_formatter.dart';
import 'expiry_formatter.dart';

/// Stripe-inspired card input form (Screen 2A).
///
/// Uses a unified card container with card number on top and
/// expiry + CVV below, separated by internal dividers.
/// Name on card is a separate field below.
class CardFormSheet extends StatefulWidget {
  final KashierSession session;
  final KashierCardHandler cardHandler;
  final VoidCallback onBack;
  final void Function(CardPaymentResponse response) onPaymentResponse;

  const CardFormSheet({
    super.key,
    required this.session,
    required this.cardHandler,
    required this.onBack,
    required this.onPaymentResponse,
  });

  @override
  State<CardFormSheet> createState() => _CardFormSheetState();
}

class _CardFormSheetState extends State<CardFormSheet> {
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();

  final _cardNumberFocus = FocusNode();
  final _expiryFocus = FocusNode();
  final _cvvFocus = FocusNode();
  final _nameFocus = FocusNode();

  bool _loading = false;
  String? _errorMessage;
  bool _saveCard = false;
  KashierCardBrand _detectedBrand = KashierCardBrand.unknown;

  // Track focus for unified container border highlight.
  bool _cardContainerFocused = false;

  // Track touched state for validation display.
  bool _cardNumberTouched = false;
  bool _expiryTouched = false;
  bool _cvvTouched = false;
  bool _nameTouched = false;

  bool get _isTestMode => KashierSDK.mode == KashierMode.test;

  @override
  void initState() {
    super.initState();
    if (widget.session.saveCard == 'forced') {
      _saveCard = true;
    }

    _cardNumberFocus.addListener(_onCardContainerFocusChanged);
    _expiryFocus.addListener(_onCardContainerFocusChanged);
    _cvvFocus.addListener(_onCardContainerFocusChanged);
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    _cardNumberFocus.dispose();
    _expiryFocus.dispose();
    _cvvFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onCardContainerFocusChanged() {
    final focused = _cardNumberFocus.hasFocus ||
        _expiryFocus.hasFocus ||
        _cvvFocus.hasFocus;
    if (focused != _cardContainerFocused) {
      setState(() => _cardContainerFocused = focused);
    }
  }

  // ── Derived state ──

  String get _digits =>
      _cardNumberController.text.replaceAll(RegExp(r'\D'), '');

  bool get _isCardNumberValid => CardValidator.validateCardNumber(_digits);

  bool get _isExpiryValid {
    final parts = _expiryController.text.split('/');
    if (parts.length != 2) return false;
    return CardValidator.validateExpiry(parts[0], parts[1]);
  }

  bool get _isCvvValid =>
      CardValidator.validateCvv(_cvvController.text, _detectedBrand);

  bool get _isNameValid => CardValidator.validateName(_nameController.text);

  bool get _isFormValid =>
      _isCardNumberValid && _isExpiryValid && _isCvvValid && _isNameValid;

  // Validation error text for below the unified container.
  String? get _cardContainerError {
    if (_cardNumberTouched && _digits.length >= 16 && !_isCardNumberValid) {
      return KashierLocalizations.invalidCardNumber(context);
    }
    if (_expiryTouched &&
        _expiryController.text.length == 5 &&
        !_isExpiryValid) {
      return KashierLocalizations.cardExpired(context);
    }
    if (_cvvTouched && _cvvController.text.length == 3 && !_isCvvValid) {
      return KashierLocalizations.invalidCvv(context);
    }
    return null;
  }

  // ── Handlers ──

  /// Fills all card fields with test data for quick testing.
  void _fillTestData() {
    _cardNumberController.text = '4508 7500 1574 1019';
    _expiryController.text = '06/27';
    _cvvController.text = '100';
    _nameController.text = 'John Doe';
    setState(() {
      _detectedBrand = CardValidator.detectBrand('4508750015741019');
      _cardNumberTouched = true;
      _expiryTouched = true;
      _cvvTouched = true;
      _nameTouched = true;
      _errorMessage = null;
    });
  }

  void _onCardNumberChanged(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    setState(() {
      _detectedBrand = CardValidator.detectBrand(digits);
      _errorMessage = null;
    });
    if (digits.length == 16) _expiryFocus.requestFocus();
  }

  void _onExpiryChanged(String value) {
    setState(() => _errorMessage = null);
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 4) _cvvFocus.requestFocus();
  }

  void _onCvvChanged(String value) {
    setState(() => _errorMessage = null);
    if (value.replaceAll(RegExp(r'\D'), '').length == 3) {
      _nameFocus.requestFocus();
    }
  }

  Future<void> _onPayTapped() async {
    if (!_isFormValid || _loading) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final expiryParts = _expiryController.text.split('/');
      final input = KashierCardInput(
        cardNumber: _digits,
        nameOnCard: _nameController.text.trim(),
        expiryMonth: expiryParts[0],
        expiryYear: expiryParts[1],
        cvv: _cvvController.text.trim(),
        saveCard: _saveCard,
      );

      final response = await widget.cardHandler.payWithNewCard(input);
      if (!mounted) return;

      if (response.isSuccess || response.needs3DS) {
        widget.onPaymentResponse(response);
      } else {
        setState(() {
          _loading = false;
          _errorMessage = KashierLocalizations.isArabic(context)
              ? response.errorMessageAr
              : response.errorMessage;
        });
      }
    } on KashierPaymentError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  // ── Build helpers ──

  /// Borderless input decoration for fields inside the unified container.
  InputDecoration _containerFieldDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: KashierColors.placeholder,
        fontSize: 15,
      ),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(minHeight: 20, minWidth: 20),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final amountStr = widget.session.amount % 1 == 0
        ? widget.session.amount.toInt().toString()
        : widget.session.amount.toStringAsFixed(2);

    final hasCustomer =
        widget.session.customer != null && widget.session.customer!.hasData;
    final showSaveCard =
        widget.session.saveCard != 'hidden' && !_isTestMode && hasCustomer;

    final containerError = _cardContainerError;
    final hasContainerError = containerError != null;

    // Container border color: error > focused > default.
    final containerBorderColor = hasContainerError
        ? KashierColors.strokeDanger
        : _cardContainerFocused
            ? KashierColors.primary
            : KashierColors.strokeInput;

    final containerBorderWidth =
        (_cardContainerFocused || hasContainerError) ? 1.5 : 1.0;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KashierDragHandle(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    GestureDetector(
                      onTap: _loading ? null : widget.onBack,
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: _loading
                            ? KashierColors.contentDisabled
                            : KashierColors.contentPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // ── Title ──
                    Text(
                      KashierLocalizations.addCard(context),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: KashierColors.contentPrimary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),

                // ── Back button ──
                const SizedBox(height: 24),

                // ── "Use Testing Data" button (test mode only) ──
                if (_isTestMode && !_loading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SizedBox(
                      height: 36,
                      child: OutlinedButton.icon(
                        onPressed: _fillTestData,
                        icon: const Icon(Icons.bug_report_outlined, size: 16),
                        label: Text(
                          KashierLocalizations.localized(
                            context,
                            en: 'Use Testing Data',
                            ar: 'استخدام بيانات اختبار',
                          ),
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: KashierColors.contentSecondary,
                          side: const BorderSide(
                            color: KashierColors.strokeInput,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ),

                // ── "Card information" label ──
                Text(
                  KashierLocalizations.localized(
                    context,
                    en: 'Card information',
                    ar: 'بيانات البطاقة',
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: KashierColors.contentSecondary,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Unified card container ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: KashierColors.surfaceSheet,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: containerBorderColor,
                      width: containerBorderWidth,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Card number row
                      TextFormField(
                        controller: _cardNumberController,
                        focusNode: _cardNumberFocus,
                        enabled: !_loading,
                        keyboardType: TextInputType.number,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                          fontSize: 15,
                          color: KashierColors.contentPrimary,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
                          CardNumberFormatter(),
                        ],
                        onChanged: _onCardNumberChanged,
                        onTap: () => setState(() => _cardNumberTouched = true),
                        decoration: _containerFieldDecoration(
                          hint: KashierLocalizations.cardNumberHint(context),
                          suffixIcon: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 12),
                            child: CardBrandIcon(
                              detectedBrand: _detectedBrand,
                              iconHeight: 18,
                            ),
                          ),
                        ),
                      ),

                      // Horizontal divider
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: containerBorderColor,
                      ),

                      // Expiry + CVV row
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            // Expiry
                            Expanded(
                              child: TextFormField(
                                controller: _expiryController,
                                focusNode: _expiryFocus,
                                enabled: !_loading,
                                keyboardType: TextInputType.number,
                                textDirection: TextDirection.ltr,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: KashierColors.contentPrimary,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[\d/]'),
                                  ),
                                  ExpiryFormatter(),
                                ],
                                onChanged: _onExpiryChanged,
                                onTap: () =>
                                    setState(() => _expiryTouched = true),
                                decoration: _containerFieldDecoration(
                                  hint:
                                      KashierLocalizations.expiryHint(context),
                                ),
                              ),
                            ),

                            // Vertical divider
                            VerticalDivider(
                              width: 1,
                              thickness: 1,
                              color: containerBorderColor,
                            ),

                            // CVV
                            Expanded(
                              child: TextFormField(
                                controller: _cvvController,
                                focusNode: _cvvFocus,
                                enabled: !_loading,
                                keyboardType: TextInputType.number,
                                textDirection: TextDirection.ltr,
                                obscureText: true,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: KashierColors.contentPrimary,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                onChanged: _onCvvChanged,
                                onTap: () => setState(() => _cvvTouched = true),
                                decoration: _containerFieldDecoration(
                                  hint: KashierLocalizations.cvv(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Validation error below the container
                if (hasContainerError)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      containerError,
                      style: const TextStyle(
                        fontSize: 12,
                        color: KashierColors.feedbackError,
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // ── Name on card ──
                Text(
                  KashierLocalizations.nameOnCard(context),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: KashierColors.contentSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  enabled: !_loading,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  style: const TextStyle(
                    fontSize: 15,
                    color: KashierColors.contentPrimary,
                  ),
                  inputFormatters: [LengthLimitingTextInputFormatter(50)],
                  onChanged: (_) => setState(() => _errorMessage = null),
                  onTap: () => setState(() => _nameTouched = true),
                  decoration: InputDecoration(
                    hintText: KashierLocalizations.nameOnCardHint(context),
                    hintStyle: const TextStyle(
                      color: KashierColors.placeholder,
                      fontSize: 15,
                    ),
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: KashierColors.strokeInput,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: KashierColors.strokeInput,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: KashierColors.primary,
                        width: 1.5,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: KashierColors.strokeDanger,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: KashierColors.strokeDanger,
                        width: 1.5,
                      ),
                    ),
                    errorText: _nameTouched &&
                            _nameController.text.isNotEmpty &&
                            !_isNameValid
                        ? KashierLocalizations.nameIsRequired(context)
                        : null,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Save card checkbox ──
                if (showSaveCard)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: GestureDetector(
                      onTap: widget.session.saveCard == 'forced' || _loading
                          ? null
                          : () => setState(() => _saveCard = !_saveCard),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _saveCard
                                  ? KashierColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _saveCard
                                    ? KashierColors.primary
                                    : KashierColors.strokeInput,
                                width: 1.5,
                              ),
                            ),
                            child: _saveCard
                                ? const Icon(
                                    Icons.check,
                                    size: 14,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  KashierLocalizations.saveThisCard(context),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: widget.session.saveCard == 'forced'
                                        ? KashierColors.contentDisabled
                                        : KashierColors.contentPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Inline API error ──
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: KashierColors.feedbackErrorLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: KashierColors.feedbackError,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: KashierColors.feedbackError,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Pay button ──
                SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isFormValid && !_loading ? _onPayTapped : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: KashierColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: KashierColors.surfaceDisabled,
                      disabledForegroundColor: KashierColors.contentDisabled,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            KashierLocalizations.payAmount(
                              context,
                              amountStr,
                              widget.session.currency,
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                // ── Branding ──
                const KashierBranding(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
