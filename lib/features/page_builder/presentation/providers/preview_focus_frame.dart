import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Align the start, even when a product grid is taller than the phone.
/// A fractional alignment can scroll deep inside a long collection.
Future<void> focusPreviewSection(BuildContext context) =>
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      alignment: 0,
    );

/// Parent-frame messages can arrive while Flutter is idle. A post-frame
/// callback alone waits indefinitely until an unrelated animation paints.
void schedulePreviewFocus(void Function() focus) {
  SchedulerBinding.instance.addPostFrameCallback((_) => focus());
  SchedulerBinding.instance.ensureVisualUpdate();
}
