import 'dart:async';

/// Subscribe before delivering the cached value. An async* initial yield leaves
/// a gap in which the broadcast notification for the first packet can be lost.
Stream<T> replayPreviewValue<T>(
  Stream<String> changes,
  String page,
  T Function() read,
) => Stream<T>.multi((output) {
  final subscription = changes.listen(
    (changedPage) {
      if (changedPage == page) output.add(read());
    },
    onError: output.addError,
    onDone: output.close,
  );
  output.add(read());
  output.onCancel = subscription.cancel;
});
