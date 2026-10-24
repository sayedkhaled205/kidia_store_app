import 'dart:async';

class ThreeDSOtpVisibilityController {
  final Duration loaderDelay;
  final Duration reconcileDelay;

  Timer? _loaderTimer;
  Timer? _reconcileTimer;
  bool _completionCandidate = false;
  bool _loaderShown = false;
  bool _reconcileRequested = false;

  ThreeDSOtpVisibilityController({
    this.loaderDelay = const Duration(seconds: 10),
    this.reconcileDelay = const Duration(seconds: 20),
  });

  void onChallengeCompletionCandidate({
    required void Function() onShowLoader,
    required void Function() onReconcileRequested,
  }) {
    _completionCandidate = true;
    _loaderTimer?.cancel();
    _reconcileTimer?.cancel();

    _loaderTimer = Timer(loaderDelay, () {
      _showLoader(onShowLoader);
    });
    _reconcileTimer = Timer(reconcileDelay, () {
      _requestReconcile(onReconcileRequested);
    });
  }

  void onChallengeStillActive() {
    _loaderTimer?.cancel();
    _reconcileTimer?.cancel();
    _loaderTimer = null;
    _reconcileTimer = null;
    _completionCandidate = false;
    _loaderShown = false;
    _reconcileRequested = false;
  }

  void onMainPageFinished(
    String? url, {
    required void Function() onReconcileRequested,
  }) {
    if (!_completionCandidate || _reconcileRequested || url == null) return;
    if (!url.contains('/3dsRedirect/')) return;
    _requestReconcile(onReconcileRequested);
  }

  void cancel() {
    _loaderTimer?.cancel();
    _reconcileTimer?.cancel();
    _loaderTimer = null;
    _reconcileTimer = null;
    _completionCandidate = false;
    _loaderShown = false;
    _reconcileRequested = false;
  }

  void _showLoader(void Function() onShowLoader) {
    if (_loaderShown || _reconcileRequested) return;
    _loaderShown = true;
    _loaderTimer?.cancel();
    _loaderTimer = null;
    onShowLoader();
  }

  void _requestReconcile(void Function() onReconcileRequested) {
    if (_reconcileRequested) return;
    _reconcileRequested = true;
    _loaderTimer?.cancel();
    _reconcileTimer?.cancel();
    _loaderTimer = null;
    _reconcileTimer = null;
    onReconcileRequested();
  }
}
