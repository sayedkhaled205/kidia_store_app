import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Native identity proof only. The merchant API exchanges this proof for its
/// own customer session; Firebase is never the app's customer session store.
abstract interface class NativeAuthSdk {
  Future<NativePhoneChallenge> startPhone({
    required Map<String, dynamic> config,
    required String phone,
    int? resendToken,
  });
  Future<String> verifyPhone(NativePhoneChallenge challenge, String code);
  Future<String> google(Map<String, dynamic> config);
  Future<void> cancel();
}

class NativePhoneChallenge {
  NativePhoneChallenge({
    required this.verificationId,
    this.resendToken,
    Future<String?>? automaticIdToken,
  }) : automaticIdToken = automaticIdToken ?? Future<String?>.value();

  /// Empty only when Android verified the phone before an SMS was necessary.
  final String verificationId;
  final int? resendToken;

  /// One automatic verification result. Null means manual code entry remains
  /// necessary, or this attempt was cancelled. Errors must be shown inline.
  final Future<String?> automaticIdToken;
}

class NativeAuthSdkException implements Exception {
  const NativeAuthSdkException(this.code);
  final String code;
  @override
  String toString() => 'NativeAuthSdkException($code)';
}

/// Small boundaries keep race/cancellation tests independent of platform SDKs.
abstract interface class NativePhoneBackend {
  Future<void> verify({
    required String phone,
    int? resendToken,
    required void Function(PhoneAuthCredential credential) completed,
    required void Function(Object error, StackTrace stack) failed,
    required void Function(String id, int? resendToken) sent,
    required void Function(String id) timedOut,
  });
  Future<String> tokenFor(PhoneAuthCredential credential);
  Future<void> signOut();
}

abstract interface class NativeGoogleBackend {
  Future<String> authenticate({
    required String serverClientId,
    String? clientId,
  });
}

typedef NativePhoneBackendFactory =
    Future<NativePhoneBackend> Function(Map<String, dynamic> firebase);

final class FirebaseNativeAuthSdk implements NativeAuthSdk {
  FirebaseNativeAuthSdk({
    NativePhoneBackendFactory? phoneBackendFactory,
    NativeGoogleBackend? googleBackend,
    TargetPlatform? platform,
    bool? isWeb,
  }) : _phoneBackendFactory =
           phoneBackendFactory ?? _FirebasePhoneBackend.create,
       _googleBackend = googleBackend ?? _GoogleBackend.instance,
       _platform = platform ?? defaultTargetPlatform,
       _isWeb = isWeb ?? kIsWeb;

  final NativePhoneBackendFactory _phoneBackendFactory;
  final NativeGoogleBackend _googleBackend;
  final TargetPlatform _platform;
  final bool _isWeb;
  int _generation = 0;
  _PhoneAttempt? _phone;

  void _checkPlatform() {
    if (_isWeb ||
        (_platform != TargetPlatform.android &&
            _platform != TargetPlatform.iOS)) {
      throw const NativeAuthSdkException('native-platform-required');
    }
  }

  Map<String, dynamic> _firebaseOptions(Map<String, dynamic> config) {
    _checkPlatform();
    final source = config['firebase'];
    if (source is! Map) {
      throw const NativeAuthSdkException('phone-not-configured');
    }
    final options = Map<String, dynamic>.from(source);
    final platformName = _platform == TargetPlatform.iOS ? 'ios' : 'android';
    final platformOptions = options[platformName];
    if (platformOptions is Map) {
      options.addAll(Map<String, dynamic>.from(platformOptions));
    }
    for (final key in ['apiKey', 'appId', 'projectId', 'messagingSenderId']) {
      if (options[key] is! String || (options[key] as String).trim().isEmpty) {
        throw const NativeAuthSdkException('phone-not-configured');
      }
    }
    // A website's Firebase app registration is not an Android/iOS app. Never
    // fall back to the default Firebase project used by push notifications.
    if (!(options['appId'] as String).contains(':$platformName:')) {
      throw const NativeAuthSdkException('phone-native-registration-required');
    }
    if (_platform == TargetPlatform.iOS &&
        (options['iosBundleId'] is! String ||
            (options['iosBundleId'] as String).trim().isEmpty)) {
      throw const NativeAuthSdkException('phone-native-registration-required');
    }
    return options;
  }

  void _checkCurrent(int generation) {
    if (generation != _generation) {
      throw const NativeAuthSdkException('cancelled');
    }
  }

  @override
  Future<NativePhoneChallenge> startPhone({
    required Map<String, dynamic> config,
    required String phone,
    int? resendToken,
  }) async {
    final firebase = _firebaseOptions(config);
    if (!RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(phone)) {
      throw const NativeAuthSdkException('invalid-phone-number');
    }
    final generation = ++_generation;
    _phone?.cancel();
    final backend = await _phoneBackendFactory(firebase);
    _checkCurrent(generation);
    final attempt = _PhoneAttempt(generation, backend);
    _phone = attempt;
    // A fast SDK callback can fail before the caller receives the challenge.
    // Register a sink immediately; the original future still reports errors.
    unawaited(attempt.automatic.future.then<void>((_) {}, onError: (_, _) {}));
    unawaited(attempt.started.future.then<void>((_) {}, onError: (_, _) {}));
    attempt.timer = Timer(const Duration(seconds: 90), () {
      if (generation != _generation) return;
      if (!attempt.started.isCompleted) {
        attempt.fail(
          const NativeAuthSdkException('verification-timeout'),
          StackTrace.current,
        );
      } else if (!attempt.automatic.isCompleted && !attempt.claimed) {
        attempt.automatic.complete(null);
      }
    });
    try {
      final launched = backend.verify(
        phone: phone,
        resendToken: resendToken,
        completed: (credential) {
          if (generation != _generation ||
              attempt.claimed ||
              attempt.automatic.isCompleted) {
            return;
          }
          attempt.claimed = true;
          unawaited(_completeAutomatically(attempt, credential));
        },
        failed: (error, stack) {
          if (generation == _generation) attempt.fail(_safeError(error), stack);
        },
        sent: (id, token) {
          if (generation != _generation || attempt.started.isCompleted) return;
          attempt.sent(id, token);
        },
        timedOut: (id) {
          if (generation != _generation || attempt.claimed) return;
          attempt.sent(id, null);
          attempt.timer?.cancel();
          if (!attempt.automatic.isCompleted) attempt.automatic.complete(null);
        },
      );
      unawaited(
        launched.then<void>(
          (_) {},
          onError: (Object error, StackTrace stack) {
            if (generation == _generation) {
              attempt.fail(_safeError(error), stack);
            }
          },
        ),
      );
    } catch (error, stack) {
      if (generation == _generation) attempt.fail(_safeError(error), stack);
    }
    _checkCurrent(generation);
    return attempt.started.future;
  }

  Future<void> _completeAutomatically(
    _PhoneAttempt attempt,
    PhoneAuthCredential credential,
  ) async {
    try {
      final token = await attempt.backend.tokenFor(credential);
      _checkCurrent(attempt.generation);
      attempt.timer?.cancel();
      attempt.sent('', null);
      if (!attempt.automatic.isCompleted) attempt.automatic.complete(token);
    } catch (error, stack) {
      if (attempt.generation == _generation) {
        attempt.claimed = false;
        attempt.fail(_safeError(error), stack);
      }
    }
  }

  @override
  Future<String> verifyPhone(
    NativePhoneChallenge challenge,
    String code,
  ) async {
    final attempt = _phone;
    if (attempt == null ||
        !identical(attempt.challenge, challenge) ||
        attempt.generation != _generation) {
      throw const NativeAuthSdkException('cancelled');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code) ||
        challenge.verificationId.isEmpty) {
      throw const NativeAuthSdkException('invalid-verification-code');
    }
    if (attempt.claimed) {
      throw const NativeAuthSdkException('verification-in-progress');
    }
    attempt.claimed = true;
    try {
      final token = await attempt.backend.tokenFor(
        PhoneAuthProvider.credential(
          verificationId: challenge.verificationId,
          smsCode: code,
        ),
      );
      _checkCurrent(attempt.generation);
      attempt.timer?.cancel();
      if (!attempt.automatic.isCompleted) attempt.automatic.complete(null);
      return token;
    } catch (error) {
      if (attempt.generation == _generation) attempt.claimed = false;
      throw _safeError(error);
    }
  }

  @override
  Future<String> google(Map<String, dynamic> config) async {
    _checkPlatform();
    final options = config['google'];
    if (options is! Map) {
      throw const NativeAuthSdkException('google-not-configured');
    }
    final serverId = options['server_client_id'];
    final clientId = _platform == TargetPlatform.iOS
        ? options['ios_client_id']
        : null;
    bool valid(Object? value) =>
        value is String &&
        RegExp(
          r'^[a-zA-Z0-9-]+\.apps\.googleusercontent\.com$',
        ).hasMatch(value);
    if (!valid(serverId) ||
        (_platform == TargetPlatform.iOS && !valid(clientId))) {
      throw const NativeAuthSdkException('google-native-registration-required');
    }
    final generation = ++_generation;
    _phone?.cancel();
    try {
      final token = await _googleBackend.authenticate(
        serverClientId: serverId as String,
        clientId: clientId as String?,
      );
      _checkCurrent(generation);
      if (token.isEmpty) throw const NativeAuthSdkException('missing-id-token');
      return token;
    } catch (error) {
      throw _safeError(error);
    }
  }

  @override
  Future<void> cancel() async {
    ++_generation;
    final attempt = _phone;
    _phone = null;
    attempt?.cancel();
    // Backend serializes this after any credential exchange still in flight.
    // The default push Firebase app is never touched.
    if (attempt != null) await attempt.backend.signOut();
  }

  static Object _safeError(Object error) {
    if (error is NativeAuthSdkException) return error;
    if (error is FirebaseAuthException) {
      return NativeAuthSdkException(error.code);
    }
    if (error is GoogleSignInException) {
      return NativeAuthSdkException(
        error.code == GoogleSignInExceptionCode.canceled
            ? 'cancelled'
            : 'google-${error.code.name}',
      );
    }
    // Provider error strings can contain account data; never surface/log them.
    return const NativeAuthSdkException('identity-provider-unavailable');
  }
}

class _PhoneAttempt {
  _PhoneAttempt(this.generation, this.backend);
  final int generation;
  final NativePhoneBackend backend;
  final started = Completer<NativePhoneChallenge>();
  final automatic = Completer<String?>();
  NativePhoneChallenge? challenge;
  Timer? timer;
  bool claimed = false;

  void sent(String id, int? token) {
    if (started.isCompleted) return;
    challenge = NativePhoneChallenge(
      verificationId: id,
      resendToken: token,
      automaticIdToken: automatic.future,
    );
    started.complete(challenge!);
  }

  void fail(Object error, StackTrace stack) {
    timer?.cancel();
    if (!started.isCompleted) started.completeError(error, stack);
    if (!automatic.isCompleted) automatic.completeError(error, stack);
  }

  void cancel() {
    timer?.cancel();
    if (!started.isCompleted) {
      started.completeError(const NativeAuthSdkException('cancelled'));
    }
    if (!automatic.isCompleted) automatic.complete(null);
  }
}

final class _FirebasePhoneBackend implements NativePhoneBackend {
  _FirebasePhoneBackend(this.auth);
  final FirebaseAuth auth;
  Future<void> _tail = Future<void>.value();
  static final _instances = <String, Future<_FirebasePhoneBackend>>{};

  static Future<NativePhoneBackend> create(Map<String, dynamic> options) {
    final fingerprint = sha256
        .convert(
          utf8.encode(
            jsonEncode([
              options['projectId'],
              options['appId'],
              options['apiKey'],
              options['messagingSenderId'],
              options['iosBundleId'],
            ]),
          ),
        )
        .toString();
    return _instances.putIfAbsent(fingerprint, () async {
      final name = 'mobishop-merchant-auth-${fingerprint.substring(0, 24)}';
      final app = await Firebase.initializeApp(
        name: name,
        options: FirebaseOptions(
          apiKey: options['apiKey'] as String,
          appId: options['appId'] as String,
          messagingSenderId: options['messagingSenderId'] as String,
          projectId: options['projectId'] as String,
          iosBundleId: options['iosBundleId'] as String?,
        ),
      );
      final backend = _FirebasePhoneBackend(FirebaseAuth.instanceFor(app: app));
      await backend.signOut();
      return backend;
    });
  }

  Future<T> _exclusive<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  @override
  Future<void> verify({
    required String phone,
    int? resendToken,
    required void Function(PhoneAuthCredential credential) completed,
    required void Function(Object error, StackTrace stack) failed,
    required void Function(String id, int? resendToken) sent,
    required void Function(String id) timedOut,
  }) => auth.verifyPhoneNumber(
    phoneNumber: phone,
    forceResendingToken: resendToken,
    verificationCompleted: completed,
    verificationFailed: (error) => failed(error, StackTrace.current),
    codeSent: sent,
    codeAutoRetrievalTimeout: timedOut,
    timeout: const Duration(seconds: 60),
  );

  @override
  Future<String> tokenFor(PhoneAuthCredential credential) =>
      _exclusive(() async {
        try {
          final result = await auth.signInWithCredential(credential);
          final token = await result.user?.getIdToken(true);
          if (token == null || token.isEmpty) {
            throw const NativeAuthSdkException('missing-id-token');
          }
          return token;
        } finally {
          await auth.signOut();
        }
      });

  @override
  Future<void> signOut() => _exclusive(auth.signOut);
}

final class _GoogleBackend implements NativeGoogleBackend {
  _GoogleBackend();
  static final instance = _GoogleBackend();
  Future<void>? _initialized;
  String? _configuration;
  bool _busy = false;

  @override
  Future<String> authenticate({
    required String serverClientId,
    String? clientId,
  }) async {
    if (_busy) throw const NativeAuthSdkException('verification-in-progress');
    final configuration = '$serverClientId|${clientId ?? ''}';
    if (_configuration != null && _configuration != configuration) {
      throw const NativeAuthSdkException('google-configuration-changed');
    }
    _busy = true;
    final google = GoogleSignIn.instance;
    try {
      _configuration = configuration;
      _initialized ??= google.initialize(
        serverClientId: serverClientId,
        clientId: clientId,
      );
      try {
        await _initialized;
      } catch (_) {
        _initialized = null;
        _configuration = null;
        rethrow;
      }
      if (!google.supportsAuthenticate()) {
        throw const NativeAuthSdkException('native-platform-required');
      }
      GoogleSignInAccount? account;
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Credential Manager's bottom sheet uses the app's registered branding.
        // Keep cancellation distinct from an unavailable sheet: dismissing it
        // must not immediately open a second account picker.
        try {
          account = await google.attemptLightweightAuthentication(
            reportAllExceptions: true,
          );
        } on GoogleSignInException catch (error) {
          if (error.code != GoogleSignInExceptionCode.uiUnavailable) rethrow;
        }
      }
      // The explicit flow also lets users add an account when none are eligible
      // for the sheet. iOS retains its native Google authentication flow.
      account ??= await google.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const NativeAuthSdkException('missing-id-token');
      }
      return token;
    } finally {
      try {
        if (_initialized != null) await google.signOut();
      } finally {
        _busy = false;
      }
    }
  }
}
