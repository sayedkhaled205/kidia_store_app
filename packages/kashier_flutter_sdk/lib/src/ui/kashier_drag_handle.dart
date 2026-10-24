import 'package:flutter/material.dart';

import 'kashier_colors.dart';

/// A shared drag handle widget used at the top of bottom sheets.
class KashierDragHandle extends StatelessWidget {
  const KashierDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: KashierColors.strokeInput,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
