import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/kashier_card.dart';
import '../kashier_colors.dart';
import '../kashier_localizations.dart';
import '../widgets/kashier_payment_method_tile.dart';
import 'saved_card_tile.dart';

// ── Layout constants ──

/// Height of a card / Add-New-Card / skeleton row.
const double _rowHeight = 56.0;

/// Minimum touch target — View-all row and CVV field height.
const double _minTouchTarget = 44.0;

/// Width of the small inline CVV field (3 centered digits).
const double _cvvFieldWidth = 72.0;

/// Spinner / row icon size.
const double _iconSize = 22.0;

/// Max height of the expanded scrollable list: 4.5 × (56 row + 8 gap).
/// The half-row peek is the scroll affordance.
const double _maxScrollHeight = 288.0;

/// How many rows show before the list collapses behind "View all".
const int _collapsedRowCount = 3;

/// Collapsible card section for the payment landing sheet.
///
/// The closed header is pixel-identical to the Wallet row (both are
/// [KashierPaymentMethodTile]). The body lists all saved cards inline —
/// the selected row shows a compact CVV field in its trailing slot — and
/// holds the "Add New Card" entry.
///
/// Owns only the expand/collapse state. Selection and CVV state live in
/// the landing sheet / orchestrator, so collapsing never resets them.
///
/// Body states:
/// 1. [loading] — skeleton rows, no Add New Card.
/// 2. Loaded with cards — card rows + View more + Add New Card.
/// 3. Loaded empty, handler ready — Add New Card only.
/// 4. [errorMessage] non-null (bootstrap failed) — inline error only;
///    the header is fully inert.
class CardAccordion extends StatefulWidget {
  /// Saved cards to list in the body.
  final List<KashierCard> savedCards;

  /// True while the saved-cards fetch is in progress.
  final bool loading;

  /// The currently selected card. Null = no selection.
  final KashierCard? selectedCard;

  /// CVV input state, owned by the landing sheet.
  final TextEditingController cvvController;
  final FocusNode cvvFocus;

  /// False while a charge is in flight or the handler isn't ready.
  /// Gates row taps, the CVV field, View more, and Add New Card.
  final bool enabled;

  /// When non-null (bootstrap failed), the body shows this localized error
  /// instead of the card list / Add New Card, and the header is inert.
  final String? errorMessage;

  /// Called when the user taps a saved card row.
  final void Function(KashierCard card) onCardTapped;

  /// Opens the new-card form. Null greys/disables the Add New Card row.
  final VoidCallback? onAddNewCard;

  /// Deletes a saved card (server call; throws on failure). Null disables
  /// BOTH delete paths — swipe and the selected row's trash icon — e.g.
  /// while a charge is in flight or the handler isn't ready.
  final Future<void> Function(KashierCard card)? onDeleteCard;

  /// Notifies the landing on CVV edits so the Pay button re-evaluates.
  final VoidCallback? onCvvChanged;

  const CardAccordion({
    super.key,
    required this.savedCards,
    required this.loading,
    this.selectedCard,
    required this.cvvController,
    required this.cvvFocus,
    required this.enabled,
    this.errorMessage,
    required this.onCardTapped,
    this.onAddNewCard,
    this.onDeleteCard,
    this.onCvvChanged,
  });

  @override
  State<CardAccordion> createState() => _CardAccordionState();
}

class _CardAccordionState extends State<CardAccordion> {
  bool _expanded = true;

  /// Whether the full card list is shown ("View all" toggled on).
  bool _showAll = false;

  /// Token of the card currently being deleted (row shows a spinner).
  String? _deletingToken;

  /// Controls the bounded inner scroll of the expanded list so "Show less"
  /// can reset the offset.
  final ScrollController _scrollController = ScrollController();

  void _toggle() => setState(() => _expanded = !_expanded);

  bool get _headerInteractive => !widget.loading && widget.errorMessage == null;

  /// Saved cards de-duplicated by token (first occurrence wins); cards with
  /// an empty token are dropped — either would break the Dismissible keys.
  List<KashierCard> get _uniqueCards {
    final seen = <String>{};
    return widget.savedCards
        .where((c) => c.cardToken.isNotEmpty && seen.add(c.cardToken))
        .toList();
  }

  @override
  void didUpdateWidget(covariant CardAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Collapse "View all" when the list shrinks back to the collapsed size —
    // delete-to-3, delete-to-0, or any external list update.
    if (_showAll && _uniqueCards.length <= _collapsedRowCount) {
      _showAll = false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // One bordered container holds the header AND the body (card rows,
    // View more, Add New Card) so the card method reads as a single block,
    // visually separated from the other method tiles.
    return Container(
      decoration: BoxDecoration(
        color: KashierColors.surfaceSheet,
        border: Border.all(color: KashierColors.strokeInput),
        borderRadius: BorderRadius.circular(12),
        boxShadow: KashierPaymentMethodTile.methodShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? _buildBody(context)
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ──

  Widget _buildHeader(BuildContext context) {
    final tile = KashierPaymentMethodTile(
      icon: Icons.credit_card_outlined,
      title: KashierLocalizations.card(context),
      subtitle: KashierLocalizations.cardSubtitle(context),
      onTap: _headerInteractive ? _toggle : null,
      trailing: _buildHeaderTrailing(),
      bordered: false, // the accordion container draws border + shadow
    );

    if (_headerInteractive) {
      return Semantics(
        button: true,
        label: KashierLocalizations.card(context),
        value: _expanded
            ? KashierLocalizations.accordionExpanded(context)
            : KashierLocalizations.accordionCollapsed(context),
        onTap: _toggle,
        child: tile,
      );
    }

    return Semantics(
      button: false,
      label: widget.loading
          ? KashierLocalizations.loadingSavedCards(context)
          : widget.errorMessage,
      child: tile,
    );
  }

  Widget _buildHeaderTrailing() {
    if (widget.loading) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: KashierColors.primary,
        ),
      );
    }
    if (widget.errorMessage != null) {
      return const Icon(
        Icons.chevron_right,
        color: KashierColors.contentDisabled,
      );
    }
    return AnimatedRotation(
      turns: _expanded ? 0.25 : 0,
      duration: const Duration(milliseconds: 200),
      child: const Icon(
        Icons.chevron_right,
        color: KashierColors.contentDisabled,
      ),
    );
  }

  // ── Body ──

  Widget _buildBody(BuildContext context) {
    final Widget content;
    if (widget.loading) {
      content = _buildLoadingBody(context);
    } else if (widget.errorMessage != null) {
      content = _buildErrorBody(context);
    } else if (_uniqueCards.isEmpty) {
      // Loaded empty / fetch failed with a ready handler — Add New Card only.
      content = _buildAddNewCardRow(context);
    } else {
      content = _buildCardsBody(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thin divider separating the header from the body content.
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: KashierColors.strokeInput,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: content,
        ),
      ],
    );
  }

  Widget _buildLoadingBody(BuildContext context) {
    return Semantics(
      label: KashierLocalizations.loadingSavedCards(context),
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _collapsedRowCount; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Container(
              height: _rowHeight,
              decoration: BoxDecoration(
                color: KashierColors.surfaceSheet,
                border: Border.all(color: KashierColors.strokeInput),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBody(BuildContext context) {
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
              widget.errorMessage!,
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

  Widget _buildCardsBody(BuildContext context) {
    final cards = _uniqueCards;
    final hasOverflow = cards.length > _collapsedRowCount;

    // Visible rows: first 3 when collapsed — but never hide the selected
    // card ("Show less" with a late selection appends it as a 4th row).
    List<KashierCard> visible;
    if (!hasOverflow || _showAll) {
      visible = cards;
    } else {
      visible = cards.take(_collapsedRowCount).toList();
      final selected = widget.selectedCard;
      if (selected != null &&
          !visible.any((c) => c.cardToken == selected.cardToken) &&
          cards.any((c) => c.cardToken == selected.cardToken)) {
        visible.add(
          cards.firstWhere((c) => c.cardToken == selected.cardToken),
        );
      }
    }

    // Bounded inner scroll only when the expanded list outgrows the cap —
    // the sheet never grows past ~4.5 rows regardless of card count.
    final Widget rows;
    if (_showAll && cards.length > _collapsedRowCount + 1) {
      rows = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _maxScrollHeight),
        child: ListView.separated(
          controller: _scrollController,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: visible.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) => _buildCardRow(context, visible[i]),
        ),
      );
    } else {
      rows = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _buildCardRow(context, visible[i]),
          ],
        ],
      );
    }

    // The toggle only earns its row when it can do something: collapse an
    // expanded list, or reveal actually-hidden cards (selected-card append
    // can leave nothing hidden even when the list overflows).
    final hiddenCount = cards.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        rows,
        if (_showAll || hiddenCount > 0) ...[
          const SizedBox(height: 8),
          _buildViewAllRow(context, hiddenCount),
        ],
        const SizedBox(height: 8),
        _buildAddNewCardRow(context),
      ],
    );
  }

  Widget _buildCardRow(BuildContext context, KashierCard card) {
    final isSelected = card.cardToken == widget.selectedCard?.cardToken;
    final isDeleting = _deletingToken == card.cardToken;

    Widget content = SavedCardTile(
      card: card,
      isSelected: isSelected,
      onTap: (widget.enabled && !isDeleting)
          ? () => widget.onCardTapped(card)
          : null,
      cvvField: isSelected ? _buildCvvField(context) : null,
    );

    if (isDeleting) {
      // Delete in flight — overlay the spinner on the dimmed tile instead of
      // swapping it out, so the row keeps its height (a selected row is
      // taller than an unselected one).
      content = Semantics(
        label: KashierLocalizations.deletingCard(context),
        liveRegion: true,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: 0.4,
              child: IgnorePointer(child: content),
            ),
            const SizedBox(
              width: _iconSize,
              height: _iconSize,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: KashierColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (widget.onDeleteCard == null) return content;

    return Semantics(
      hint: KashierLocalizations.swipeToDelete(context),
      child: Dismissible(
        key: ValueKey(card.cardToken),
        direction: DismissDirection.endToStart,
        // Higher than the 0.4 default — a physical buffer against accidental
        // swipe-deletes (the confirm dialog stays the final guard).
        dismissThresholds: const {DismissDirection.endToStart: 0.55},
        confirmDismiss: (_) => _confirmAndDelete(card),
        background: Container(
          decoration: BoxDecoration(
            color: KashierColors.feedbackError,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsetsDirectional.only(end: 20),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        child: content,
      ),
    );
  }

  /// Shared delete flow for both the trash icon and swipe-to-delete:
  /// confirm dialog → server delete → parent removes the card from
  /// [CardAccordion.savedCards]. Returns true only when the card was
  /// actually deleted (Dismissible uses this as its dismiss verdict).
  Future<bool> _confirmAndDelete(KashierCard card) async {
    final onDelete = widget.onDeleteCard;
    if (onDelete == null || _deletingToken != null) return false;

    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        semanticLabel: KashierLocalizations.delete(ctx),
        title: Text(KashierLocalizations.delete(ctx)),
        content: Text(
          KashierLocalizations.deleteCardConfirm(ctx, card.last4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(KashierLocalizations.cancel(ctx)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              KashierLocalizations.delete(ctx),
              style: const TextStyle(color: KashierColors.feedbackError),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    setState(() => _deletingToken = card.cardToken);
    try {
      await onDelete(card);
      return true;
    } catch (_) {
      // Server delete failed — keep the row and tell the user.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(KashierLocalizations.deleteCardFailed(context)),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _deletingToken = null);
    }
  }

  /// "View N more cards" / "Show less" toggle row. [hiddenCount] is how
  /// many cards are currently collapsed behind the toggle.
  Widget _buildViewAllRow(BuildContext context, int hiddenCount) {
    final label = _showAll
        ? KashierLocalizations.showLess(context)
        : KashierLocalizations.viewAllCards(context, hiddenCount);

    void toggle() {
      setState(() => _showAll = !_showAll);
      // Collapsing tears down the inner ListView — reset the offset so a
      // later re-expand starts from the top.
      if (!_showAll && _scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }

    return Semantics(
      button: true,
      label: label,
      value: _showAll
          ? KashierLocalizations.accordionExpanded(context)
          : KashierLocalizations.accordionCollapsed(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.enabled ? toggle : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: _minTouchTarget,
            decoration: BoxDecoration(
              border: Border.all(color: KashierColors.strokeInput),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: KashierColors.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showAll
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 18,
                  color: KashierColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Add New Card" row with the same dimensions as a saved card row
  /// (56-high, full width, radius 12). Tinted when enabled, greyed when
  /// [onAddNewCard] is null.
  Widget _buildAddNewCardRow(BuildContext context) {
    final enabled = widget.onAddNewCard != null;
    final accent =
        enabled ? KashierColors.primary : KashierColors.contentDisabled;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onAddNewCard,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: _rowHeight,
          decoration: BoxDecoration(
            color: enabled
                ? KashierColors.primary.withValues(alpha: 0.04)
                : KashierColors.surfaceDisabled,
            border: Border.all(
              color: enabled
                  ? KashierColors.primary.withValues(alpha: 0.25)
                  : KashierColors.strokeInput,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.add_circle, color: accent, size: _iconSize),
              const SizedBox(width: 12),
              Text(
                KashierLocalizations.addNewCard(context),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCvvField(BuildContext context) {
    return SizedBox(
      width: _cvvFieldWidth,
      height: _minTouchTarget,
      child: Semantics(
        label: KashierLocalizations.cvv(context),
        textField: true,
        child: TextField(
          controller: widget.cvvController,
          focusNode: widget.cvvFocus,
          obscureText: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr, // CVV always LTR, even in Arabic
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          decoration: InputDecoration(
            hintText: KashierLocalizations.cvv(context),
            hintStyle: const TextStyle(
              color: KashierColors.placeholder,
              fontSize: 14,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: KashierColors.strokeInput),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: KashierColors.strokeInput),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: KashierColors.primary,
                width: 1.5,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: KashierColors.strokeInput),
            ),
          ),
          enabled: widget.enabled,
          onChanged: (_) => widget.onCvvChanged?.call(),
        ),
      ),
    );
  }
}
