import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'kashier_colors.dart';

/// "Secured by Kashier" branding footer used on all payment sheets.
/// Renders the Kashier-provided SVG wordmark.
class KashierBranding extends StatelessWidget {
  const KashierBranding({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.lock_outline,
            size: 14,
            color: KashierColors.contentHint,
          ),
          const SizedBox(width: 6),
          SvgPicture.asset(
            'assets/icons/secured-by-kashier.svg',
            package: 'kashier_flutter_sdk',
            height: 15,
          ),
        ],
      ),
    );
  }
}
