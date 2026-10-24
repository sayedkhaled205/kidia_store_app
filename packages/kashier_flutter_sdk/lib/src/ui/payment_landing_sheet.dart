import 'package:flutter/material.dart';

import '../../models/kashier_payment_error.dart';
import '../models/card_payment_response.dart';
import '../models/kashier_card.dart';
import '../payment_handler/apple_pay/kashier_apple_pay_button.dart';
import '../payment_handler/card/kashier_card_handler.dart';
import 'card/card_accordion.dart';
import 'kashier_branding.dart';
import 'kashier_colors.dart';
import 'kashier_drag_handle.dart';
import 'kashier_localizations.dart';
import 'widgets/kashier_payment_method_tile.dart';

/// The consolidated landing screen shown when [KashierSDK.startPayment] is
/// called. Stripe-inspired layout:
///
/// - Store name + amount
/// - Apple Pay button (if available)
/// - Card accordion (saved cards inline + Add New Card), or a plain Card
///   tile when saved-card retrieval is off
/// - Wallet tile
/// - Primary "Pay" button at the bottom (enabled only when a card is
///   selected and its CVV is filled)
class PaymentLandingSheet extends StatefulWidget {
  /// Store name from the session.
  final String storeName;

  /// Payment amount.
  final double amount;

  /// Currency code (e.g., "EGP").
  final String currency;

  /// Whether Apple Pay is available on this device.
  final bool applePayAvailable;

  /// Whether wallet payment is available.
  final bool walletAvailable;

  /// Whether card payment is available.
  final bool cardAvailable;

  /// Saved cards fetched from the backend. Empty if none / not enabled.
  final List<KashierCard> savedCards;

  /// The currently selected saved card. Null = no selection (cards are
  /// never pre-selected).
  final KashierCard? selectedCard;

  /// True when the session retrieves saved cards — the accordion path is
  /// active even if the fetch ultimately returns empty.
  final bool useSavedCardsAccordion;

  /// True while the saved-cards fetch is in progress.
  final bool savedCardsLoading;

  /// True when the card handler was created AND `startPayment()` succeeded.
  /// When false (and not loading), the card section offers no Add New Card /
  /// saved-card actions — never a dead-end tap.
  final bool cardHandlerReady;

  /// True when the card bootstrap finished and the handler is not ready.
  /// Drives the localized cardUnavailable() error on both the accordion and
  /// the off-fetch plain-tile paths.
  final bool cardBootstrapFailed;

  /// Card handler used to charge the selected saved card. Required when
  /// [savedCards] is non-empty.
  final KashierCardHandler? cardHandler;

  /// Called when the user taps the Apple Pay button.
  final VoidCallback? onApplePaySelected;

  /// Called when the user taps the "New card" tile.
  final VoidCallback? onCardSelected;

  /// Called when the user taps the Wallet tile.
  final VoidCallback? onWalletSelected;

  /// Called when the user taps a saved card row in the accordion.
  final void Function(KashierCard card) onSavedCardTapped;

  /// Deletes a saved card (server call; throws on failure). Passed through
  /// to the accordion's swipe / trash delete paths.
  final Future<void> Function(KashierCard card)? onDeleteSavedCard;

  /// Called with the result of a saved-card charge attempt (success or 3DS).
  /// Inline errors (FAILURE / AUTH_UNSUCCESSFUL) are shown inside this sheet.
  final void Function(CardPaymentResponse response)? onSavedCardPaymentResponse;

  const PaymentLandingSheet({
    super.key,
    required this.storeName,
    required this.amount,
    required this.currency,
    this.applePayAvailable = false,
    this.walletAvailable = false,
    this.cardAvailable = false,
    this.savedCards = const [],
    this.selectedCard,
    required this.useSavedCardsAccordion,
    this.savedCardsLoading = false,
    this.cardHandlerReady = false,
    this.cardBootstrapFailed = false,
    this.cardHandler,
    this.onApplePaySelected,
    this.onCardSelected,
    this.onWalletSelected,
    required this.onSavedCardTapped,
    this.onDeleteSavedCard,
    this.onSavedCardPaymentResponse,
  });

  @override
  State<PaymentLandingSheet> createState() => _PaymentLandingSheetState();
}

class _PaymentLandingSheetState extends State<PaymentLandingSheet> {
  final _cvvController = TextEditingController();
  final _cvvFocus = FocusNode();

  bool _loading = false;
  String? _errorMessage;

  bool get _hasSavedCards => widget.savedCards.isNotEmpty;
  bool get _hasOtherMethods => widget.cardAvailable || widget.walletAvailable;
  bool get _cvvValid => _cvvController.text.length == 3;

  /// Gates every card action (Add New Card, saved-row taps, View more).
  bool get _cardActionsEnabled => widget.cardHandlerReady && !_loading;

  /// Whether the inline Pay button (saved-card flow) is shown: visible (and
  /// disabled) during loading, visible when cards exist, hidden when
  /// loaded-empty.
  bool get _showPayButton =>
      widget.useSavedCardsAccordion &&
      (widget.savedCardsLoading || widget.savedCards.isNotEmpty);

  @override
  void initState() {
    super.initState();
    // Returning from another screen may recreate this State with a
    // selection already set — didUpdateWidget never fires then.
    if (widget.selectedCard != null) _scheduleCvvFocus();
  }

  @override
  void didUpdateWidget(covariant PaymentLandingSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCard?.cardToken != widget.selectedCard?.cardToken) {
      // Card switched — reset CVV and error so button re-disables.
      _cvvController.clear();
      _errorMessage = null;
      if (widget.selectedCard != null) _scheduleCvvFocus();
    }
  }

  void _scheduleCvvFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cvvFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _cvvController.dispose();
    _cvvFocus.dispose();
    super.dispose();
  }

  Future<void> _onPaySavedCard() async {
    final handler = widget.cardHandler;
    final selected = widget.selectedCard;
    final onResponse = widget.onSavedCardPaymentResponse;
    if (handler == null || selected == null || onResponse == null) return;
    if (!widget.cardHandlerReady || _loading || !_cvvValid) return;

    final cvv = _cvvController.text.trim();

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final response = await handler.payWithSavedCard(
        cardToken: selected.cardToken,
        cvv: cvv,
      );
      if (!mounted) return;

      if (response.isSuccess || response.needs3DS) {
        onResponse(response);
      } else {
        setState(() {
          _loading = false;
          _cvvController.clear();
          _errorMessage = KashierLocalizations.isArabic(context)
              ? response.errorMessageAr
              : response.errorMessage;
        });
      }
    } on KashierPaymentError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _cvvController.clear();
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _cvvController.clear();
        _errorMessage = e.toString();
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const KashierDragHandle(),
                const SizedBox(height: 20),

                // Store name
                Text(
                  widget.storeName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: KashierColors.contentPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),

                // Amount + currency
                Text(
                  '$amountStr ${KashierLocalizations.currencyDisplay(context, widget.currency)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: KashierColors.contentPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // ── Wallet tile (first), then the card section ──
                if (widget.walletAvailable) ...[
                  KashierPaymentMethodTile(
                    icon: Icons.account_balance_wallet_outlined,
                    title: KashierLocalizations.wallet(context),
                    subtitle: KashierLocalizations.walletSubtitle(context),
                    onTap: _loading ? null : widget.onWalletSelected,
                  ),
                  if (widget.cardAvailable) const SizedBox(height: 10),
                ],

                // ── Card section (accordion or plain tile) ──
                if (widget.cardAvailable) _buildCardSection(context),

                // ── Inline error (from saved card charge failure) ──
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
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
                ],

                // ── Apple Pay button — above the main pay button ──
                if (widget.applePayAvailable) ...[
                  if (_hasSavedCards || _hasOtherMethods)
                    const SizedBox(height: 16),
                  KashierApplePayButton(
                    onPressed: _loading ? null : widget.onApplePaySelected,
                  ),
                ],

                // ── Pay button (saved card flow) ──
                if (_showPayButton) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.cardHandlerReady &&
                              widget.selectedCard != null &&
                              _cvvValid &&
                              !_loading
                          ? _onPaySavedCard
                          : null,
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
                                widget.currency,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Branding
                const KashierBranding(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the card section: accordion when saved-card retrieval is on,
  /// otherwise a plain Card tile gated by handler readiness. A failed
  /// bootstrap replaces either with the localized cardUnavailable() error.
  Widget _buildCardSection(BuildContext context) {
    if (widget.useSavedCardsAccordion) {
      return CardAccordion(
        savedCards: widget.savedCards,
        loading: widget.savedCardsLoading,
        selectedCard: widget.selectedCard,
        cvvController: _cvvController,
        cvvFocus: _cvvFocus,
        enabled: _cardActionsEnabled,
        errorMessage: widget.cardBootstrapFailed
            ? KashierLocalizations.cardUnavailable(context)
            : null,
        onCardTapped: widget.onSavedCardTapped,
        onAddNewCard: _cardActionsEnabled ? widget.onCardSelected : null,
        onDeleteCard: _cardActionsEnabled ? widget.onDeleteSavedCard : null,
        onCvvChanged: () => setState(() {}),
      );
    }

    // retrieveSavedCard off: plain Card tile → form. Three sub-states:
    // bootstrapping → greyed tile; ready → enabled tile; failed → error.
    if (widget.cardBootstrapFailed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                KashierLocalizations.cardUnavailable(context),
                style: const TextStyle(
                  fontSize: 13,
                  color: KashierColors.feedbackError,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return KashierPaymentMethodTile(
      icon: Icons.credit_card_outlined,
      title: KashierLocalizations.card(context),
      subtitle: KashierLocalizations.cardSubtitle(context),
      enabled: widget.cardHandlerReady,
      onTap: _cardActionsEnabled ? widget.onCardSelected : null,
    );
  }
}
