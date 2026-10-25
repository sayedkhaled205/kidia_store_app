import 'package:flutter/scheduler.dart';

/// Parent-frame messages can arrive while Flutter is idle. A post-frame
/// callback alone waits indefinitely until an unrelated animation paints.
void schedulePreviewFocus(void Function() focus) {
  SchedulerBinding.instance.addPostFrameCallback((_) => focus());
  SchedulerBinding.instance.ensureVisualUpdate();
}
