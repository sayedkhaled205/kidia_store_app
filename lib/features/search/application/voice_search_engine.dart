import 'package:speech_to_text/speech_to_text.dart';

abstract interface class VoiceSearchEngine {
  Future<bool> start({
    required String language,
    required void Function(String) onWords,
    required void Function() onError,
    required void Function() onDone,
  });
  Future<void> cancel();
  Future<void> stop();
}

/// One recognizer per application; callbacks are scoped to the active dialog.
class PlatformVoiceSearch implements VoiceSearchEngine {
  PlatformVoiceSearch._();
  static final PlatformVoiceSearch instance = PlatformVoiceSearch._();
  final SpeechToText _speech = SpeechToText();
  void Function(String)? _words;
  void Function()? _error;
  void Function()? _done;
  bool _active = false;
  int _generation = 0;

  @override
  Future<bool> start({
    required String language,
    required void Function(String) onWords,
    required void Function() onError,
    required void Function() onDone,
  }) async {
    if (_active) return false;
    final generation = ++_generation;
    _active = true;
    _words = onWords;
    _error = onError;
    _done = onDone;
    try {
      final available = await _speech.initialize(
        onError: (_) {
          _active = false;
          _error?.call();
        },
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _active = false;
            _done?.call();
          }
        },
      );
      if (generation != _generation) return false;
      if (!available || !_active) {
        _active = false;
        return false;
      }
      final locales = await _speech.locales();
      String? localeId;
      for (final locale in locales) {
        if (locale.localeId
                .toLowerCase()
                .replaceAll('_', '-')
                .split('-')
                .first ==
            language.toLowerCase()) {
          localeId = locale.localeId;
          break;
        }
      }
      if (!_active || generation != _generation) return false;
      await _speech.listen(
        onResult: (result) { if (generation == _generation) _words?.call(result.recognizedWords); },
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          partialResults: true,
          cancelOnError: true,
        ),
      );
      return true;
    } catch (_) {
      if (generation != _generation) return false;
      _active = false;
      _error?.call();
      return false;
    }
  }

  @override
  Future<void> cancel() async {
    _generation++;
    _active = false;
    _words = null;
    _error = null;
    _done = null;
    try { await _speech.cancel(); } catch (_) { /* Closing remains safe if the service is unavailable. */ }
  }

  @override
  Future<void> stop() async {
    await _speech.stop();
  }
}
