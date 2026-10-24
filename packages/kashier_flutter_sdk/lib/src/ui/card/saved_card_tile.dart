import 'package:flutter/material.dart';

import '../../models/kashier_card.dart';
import '../kashier_colors.dart';

// ── Layout constants ──

/// Height of the compact (unselected) row.
const double _rowHeight = 56.0;

/// Height of the expanded (selected) row.
const double _expandedLine1Height = 44.0;

/// A saved-card row in the payment accordion.
///
/// Two visual states:
/// - **Unselected:** compact 56-high single line — brand icon + "•••• LAST4".
/// - **Selected:** expands to a single 44-high line (Stripe-style active card):
///   brand icon → number → expiry MM/YY → small inline CVV field ([cvvField]),
///   pinned to the trailing edge. Deletion is swipe-only (handled by the parent
///   accordion's `Dismissible`); there is no inline trash affordance.
class SavedCardTile extends StatelessWidget {
  final KashierCard card;
  final bool isSelected;
  final VoidCallback? onTap;

  /// The small inline CVV field, rendered beside the expiry when selected.
  final Widget? cvvField;

  const SavedCardTile({
    super.key,
    required this.card,
    this.isSelected = false,
    this.onTap,
    this.cvvField,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        isSelected ? KashierColors.primary : KashierColors.strokeInput;
    final borderWidth = isSelected ? 1.5 : 1.0;

    return Semantics(
      selected: isSelected,
      label: '•••• ${card.last4}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected
                  ? KashierColors.primary.withValues(alpha: 0.04)
                  : KashierColors.surfaceSheet,
              border: Border.all(color: borderColor, width: borderWidth),
              borderRadius: BorderRadius.circular(12),
            ),
            // Animates the 56 ⇄ ~104 height change on (de)selection.
            // AnimatedSize manages its own ticker — no TickerProvider needed.
            child: AnimatedSize(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeInOut,
              clipBehavior: Clip.hardEdge,
              alignment: Alignment.topCenter,
              child:
                  isSelected ? _buildExpanded(context) : _buildCompact(context),
            ),
          ),
        ),
      ),
    );
  }

  /// Unselected: single 56-high line.
  Widget _buildCompact(BuildContext context) {
    return Container(
      height: _rowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildBrandIcon(card.brand),
          const SizedBox(width: 12),
          _buildNumber(),
        ],
      ),
    );
  }

  /// Selected: brand icon → number → expiry → small CVV field, single line.
  Widget _buildExpanded(BuildContext context) {
    final expiry = (card.expiryMonth != null && card.expiryYear != null)
        ? '${card.expiryMonth}/${card.expiryYear}'
        : null;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 8, 6),
      child: SizedBox(
        height: _expandedLine1Height,
        child: Row(
          children: [
            _buildBrandIcon(card.brand),
            const SizedBox(width: 12),
            _buildNumber(),
            const Spacer(),
            if (expiry != null) ...[
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  expiry,
                  style: const TextStyle(
                    fontSize: 13,
                    color: KashierColors.contentSecondary,
                  ),
                ),
              ),
            ],
            if (cvvField != null) ...[
              const SizedBox(width: 12),
              cvvField!,
            ],
          ],
        ),
      ),
    );
  }

  /// •••• LAST4 — always LTR so digits/dots keep order in Arabic.
  Widget _buildNumber() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        '••••  ${card.last4}',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: KashierColors.contentPrimary,
        ),
      ),
    );
  }

  /// Builds a small brand icon for the given card brand.
  static Widget _buildBrandIcon(KashierCardBrand brand) {
    final assetName = switch (brand) {
      KashierCardBrand.visa => 'visa',
      KashierCardBrand.mastercard => 'mastercard',
      KashierCardBrand.meeza => 'meeza',
      KashierCardBrand.unknown => null,
    };

    if (assetName == null) {
      return const SizedBox(
        width: 32,
        height: 20,
        child: Icon(
          Icons.credit_card,
          size: 20,
          color: KashierColors.contentSecondary,
        ),
      );
    }

    return SizedBox(
      width: 32,
      height: 20,
      child: Image.asset(
        'assets/icons/$assetName.png',
        package: 'kashier_flutter_sdk',
        height: 20,
        fit: BoxFit.contain,
      ),
    );
  }
}
