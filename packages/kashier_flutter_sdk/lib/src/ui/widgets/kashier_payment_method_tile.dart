import 'package:flutter/material.dart';

import '../kashier_colors.dart';

/// Reusable payment method tile used on the landing sheet.
///
/// Shows an icon container, title, subtitle, and chevron.
/// Supports Card, Wallet, and future methods.
class KashierPaymentMethodTile extends StatelessWidget {
  /// The icon to display in the leading container.
  final IconData icon;

  /// The method title (e.g., "Card", "Wallet").
  final String title;

  /// The method subtitle (e.g., "Visa, Mastercard & more").
  final String subtitle;

  /// Called when the tile is tapped.
  final VoidCallback? onTap;

  /// Optional override for the icon container background color.
  final Color? iconBackgroundColor;

  /// Optional override for the icon color.
  final Color? iconColor;

  /// Optional trailing widget rendered in place of the default chevron.
  /// When null, the tile keeps the hardcoded [Icons.chevron_right].
  final Widget? trailing;

  /// Visual enabled state. When false, the icon, icon background, title, and
  /// subtitle render in disabled colors. Does NOT force [onTap] null —
  /// callers remain responsible for passing the appropriate [onTap].
  final bool enabled;

  /// Whether the tile draws its own background, border, and soft shadow.
  /// The card accordion passes false — its outer container draws them.
  final bool bordered;

  /// Soft shadow shared by all bordered payment-method surfaces.
  static const List<BoxShadow> methodShadow = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  const KashierPaymentMethodTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.iconBackgroundColor,
    this.iconColor,
    this.trailing,
    this.enabled = true,
    this.bordered = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 64,
          decoration: bordered
              ? BoxDecoration(
                  color: KashierColors.surfaceSheet,
                  border: Border.all(color: KashierColors.strokeInput),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: methodShadow,
                )
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: enabled
                      ? (iconBackgroundColor ??
                          KashierColors.primary.withValues(alpha: 0.08))
                      : KashierColors.surfaceDisabled,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: enabled
                      ? (iconColor ?? KashierColors.primary)
                      : KashierColors.contentDisabled,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: enabled
                            ? KashierColors.contentPrimary
                            : KashierColors.contentDisabled,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: enabled
                            ? KashierColors.contentSecondary
                            : KashierColors.contentDisabled,
                      ),
                    ),
                  ],
                ),
              ),
              trailing ??
                  const Icon(
                    Icons.chevron_right,
                    color: KashierColors.contentDisabled,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
