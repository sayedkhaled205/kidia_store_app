import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/kashier_payment_error.dart';
import 'kashier_branding.dart';
import 'kashier_colors.dart';
import 'kashier_drag_handle.dart';
import 'kashier_localizations.dart';

/// Bottom sheet for entering a phone number for wallet payment.
class WalletPhoneInputSheet extends StatefulWidget {
  /// The payment amount to display on the Pay button.
  final double amount;

  /// The currency code (e.g., "EGP").
  final String currency;

  /// Optional phone number to pre-fill when the sheet opens (e.g. when the
  /// user returns from the waiting screen after cancelling a wallet attempt).
  final String? initialPhoneNumber;

  /// Called when the user taps Pay with a validated phone number.
  final Future<void> Function(String phoneNumber) onPay;

  /// Called when the user taps Back.
  final VoidCallback onBack;

  const WalletPhoneInputSheet({
    super.key,
    required this.amount,
    required this.currency,
    this.initialPhoneNumber,
    required this.onPay,
    required this.onBack,
  });

  @override
  State<WalletPhoneInputSheet> createState() => _WalletPhoneInputSheetState();
}

class _WalletPhoneInputSheetState extends State<WalletPhoneInputSheet> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _errorMessage;

  bool get _isPhoneValid =>
      _validateEgyptianPhone(_phoneController.text) == null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPhoneNumber;
    if (initial != null && initial.isNotEmpty) {
      _phoneController.text = initial;
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String? _validateEgyptianPhone(String? value) {
    final phone = (value ?? '').trim();
    if (phone.isEmpty) return '';
    final regex = RegExp(r'^01[0125]\d{8}$');
    if (!regex.hasMatch(phone)) {
      return KashierLocalizations.invalidPhone(context);
    }
    return null;
  }

  Future<void> _onPayTapped() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await widget.onPay(_phoneController.text.trim());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e is KashierPaymentError ? e.message : e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final amountStr = widget.amount % 1 == 0
        ? widget.amount.toInt().toString()
        : widget.amount.toStringAsFixed(2);

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
          child: Form(
            key: _formKey,
            // Scroll so content stays reachable when the overlay's
            // max-height cap binds (small screens with keyboard open).
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const KashierDragHandle(),
                  const SizedBox(height: 20),
                  // ── Header: back icon + title ──
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
                      Text(
                        KashierLocalizations.payWithWallet(context),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: KashierColors.contentPrimary,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Amount display
                  Text(
                    '$amountStr ${KashierLocalizations.currencyDisplay(context, widget.currency)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: KashierColors.contentPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Phone number input
                  TextFormField(
                    controller: _phoneController,
                    enabled: !_loading,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    validator: _validateEgyptianPhone,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: KashierLocalizations.phoneLabel(context),
                      hintText: KashierLocalizations.phoneHint(context),
                      hintStyle: const TextStyle(
                        color: KashierColors.placeholder,
                      ),
                      prefixIcon: const Icon(Icons.phone_outlined),
                      filled: true,
                      fillColor: Colors.transparent,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: KashierColors.strokeInput,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: KashierColors.primary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: KashierColors.strokeDanger,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: KashierColors.strokeDanger,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Error message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: KashierColors.feedbackError,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Pay button
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed:
                          _isPhoneValid && !_loading ? _onPayTapped : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: KashierColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: KashierColors.surfaceDisabled,
                        disabledForegroundColor: KashierColors.contentDisabled,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                                widget.currency,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  // Branding
                  const KashierBranding(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
