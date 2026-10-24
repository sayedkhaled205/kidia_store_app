import 'package:flutter/material.dart';

import '../../models/kashier_card.dart';

/// Displays card brand icons (Visa, Mastercard, Meeza).
///
/// Stripe-style behavior:
/// - No brand detected → all icons shown at full opacity
/// - Brand detected → matching icon shown normally, non-matching icons
///   scale down and fade out so the detected brand is unambiguous
class CardBrandIcon extends StatelessWidget {
  final KashierCardBrand? detectedBrand;
  final double iconHeight;

  const CardBrandIcon({
    super.key,
    this.detectedBrand,
    this.iconHeight = 20,
  });

  @override
  Widget build(BuildContext context) {
    final showAll =
        detectedBrand == null || detectedBrand == KashierCardBrand.unknown;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _brandImage('visa', KashierCardBrand.visa, showAll),
        const SizedBox(width: 4),
        _brandImage('mastercard', KashierCardBrand.mastercard, showAll),
        const SizedBox(width: 4),
        _brandImage('meeza', KashierCardBrand.meeza, showAll),
      ],
    );
  }

  Widget _brandImage(String assetName, KashierCardBrand brand, bool showAll) {
    final isMatch = detectedBrand == brand;

    // When showing all, full opacity. When a brand is detected:
    // - matching icon: full opacity + slight scale up
    // - non-matching: shrink away to 0
    final double opacity = showAll ? 1.0 : (isMatch ? 1.0 : 0.0);
    final double scale = showAll ? 1.0 : (isMatch ? 1.0 : 0.0);

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 200),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: opacity == 0.0 && scale == 0.0
              ? const SizedBox.shrink()
              : Image.asset(
                  'assets/icons/$assetName.png',
                  package: 'kashier_flutter_sdk',
                  height: iconHeight,
                  fit: BoxFit.contain,
                ),
        ),
      ),
    );
  }
}
