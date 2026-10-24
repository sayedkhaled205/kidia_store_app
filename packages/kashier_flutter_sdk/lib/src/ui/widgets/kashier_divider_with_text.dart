import 'package:flutter/material.dart';

import '../kashier_colors.dart';

/// A horizontal divider with centered text (e.g., "Or pay using").
class KashierDividerWithText extends StatelessWidget {
  /// The text to display between the divider lines.
  final String text;

  const KashierDividerWithText({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            color: KashierColors.strokeInput,
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: KashierColors.contentHint,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const Expanded(
          child: Divider(
            color: KashierColors.strokeInput,
            thickness: 1,
          ),
        ),
      ],
    );
  }
}
