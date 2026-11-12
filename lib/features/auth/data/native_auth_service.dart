// Keep the public dependency injection names separate from private storage.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/entities/auth_session.dart';
import '../domain/entities/native_auth.dart';
import '../domain/repositories/auth_repository.dart';
import 'native_auth_sdk.dart';
import 'network/auth_api_transport.dart';
import 'storage/auth_session_store.dart';
import 'storage/last_login_method_store.dart';

/// Exchanges native identity proofs only with the configured merchant.
/// Results remain provisional until the caller explicitly commits one.
class NativeAuthService
    implements
        NativeAuthActions,
        NativePhoneEnrollmentActions,
        NativeExistingPhoneGoogleActions,
        NativeFacebookAuthActions,
        NativeAppleAuthActions {
  NativeAuthService({
    required Uri storeUri,
    required Dio dio,
    required NativeAuthSdk sdk,
    required AuthSessionStore sessionStore,
    AuthApiTransport? legacyTransport,
    Future<void> Function(AuthSession)? onCommitted,
    Future<void> Function(LastLoginMethod)? rememberMethod,
    String? platform,
  }) : _store = _validateStore(storeUri),
       _dio = dio,
       _sdk = sdk,
       _sessions = sessionStore,
       _legacyTransport = legacyTransport,
       _onCommitted = onCommitted,
       _rememberMethod = rememberMethod ?? LastLoginMethodStore(storeUri).save,
       _platform =
           platform ??
           (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');

  final Uri _store;
  final Dio _dio;
  final NativeAuthSdk _sdk;
  final AuthSessionStore _sessions;
  final AuthApiTransport? _legacyTransport;
  final Future<void> Function(AuthSession)? _onCommitted;
  final Future<void> Function(LastLoginMethod) _rememberMethod;
  final String _platform;
  Future<NativeAuthConfig>? _configuration;
  bool _legacy = false;
  String? _legacyCreateEmail;
  _Attempt _attempt = _Attempt();
  _PhoneOperation? _phone;
  _Continuation? _continuation;
  final _owners = Expando<_Attempt>();
  final _commits = Expando<Future<AuthSession>>();
  final Map<String, Future<NativeAuthResult>> _ticketRequests = {};

  AuthApiTransport get _old =>
      _legacyTransport ?? DioAuthApiTransport(storeUri: _store, dio: _dio);

  @override
  Future<NativeAuthConfig> config() =>
      _configuration ??= _loadConfig().catchError((Object error) {
        _configuration = null;
        throw _safe(error);
      });

  Future<NativeAuthConfig> _loadConfig() async {
    try {
      final json = await _request('config', method: 'GET');
      if (json['version'] != 1 ||
          json['enabled'] is! bool ||
          json['methods'] is! Map) {
        throw const FormatException('Invalid native configuration.');
      }
      final recoveryUrl = json['password_reset_url'];
      final recovery = recoveryUrl is String && recoveryUrl.length <= 2048
          ? Uri.tryParse(recoveryUrl)
          : null;
      if (recovery != null &&
          recovery.hasAuthority &&
          recovery.host.isNotEmpty) {
        try {
          _checkOrigin(recovery);
        } on AuthRepositoryException {
          json['password_reset_url'] = '';
        }
      } else {
        json['password_reset_url'] = '';
      }
      return NativeAuthConfig.fromJson(json);
    } on AuthRepositoryException catch (error) {
      if (error.statusCode != 404) rethrow;
      _legacy = true;
      return const NativeAuthConfig(
        methods: {'email_password': true, 'registration': true},
      );
    }
  }

  _Attempt _restart() {
    _attempt.cancel();
    _attempt = _Attempt();
    _phone = null;
    _continuation = null;
    _ticketRequests.clear();
    return _attempt;
  }

  void _active(_Attempt attempt) {
    if (!identical(attempt, _attempt) || attempt.cancelled.isCompleted) {
      throw _cancelled;
    }
  }

  Future<T> _wait<T>(Future<T> operation, _Attempt attempt) {
    _active(attempt);
    return Future.any<T>([
      operation,
      attempt.cancelled.future.then<T>((_) => throw _cancelled),
    ]).then((value) {
      _active(attempt);
      return value;
    });
  }

  Future<T> _run<T>(_Attempt attempt, Future<T> Function() work) async {
    try {
      return await _wait(work(), attempt);
    } catch (error) {
      throw _safe(error);
    }
  }

  @override
  Future<NativeAuthIdentity> identify(String identifier) {
    final attempt = _restart();
    attempt.method = identifier.contains('@')
        ? LastLoginMethod.email
        : LastLoginMethod.phone;
    _legacyCreateEmail = null;
    return _run(attempt, () async {
      await _wait(_sdk.cancel(), attempt);
      await _wait(config(), attempt);
      if (_legacy) {
        final identity = await _wait(_old.identify(identifier.trim()), attempt);
        _legacyCreateEmail = identity.isRegistered
            ? null
            : identity.email.toLowerCase();
        return NativeAuthIdentity(
          identifier: identity.email,
          kind: 'email',
          methods: [identity.isRegistered ? 'password' : 'create_password'],
        );
      }
      final json = await _post('identify', attempt, {
        'identifier': identifier.trim(),
        'supports_email_password_recovery': true,
        'supports_phone_registration_recovery': true,
      });
      return NativeAuthIdentity.fromJson(json);
    });
  }

  @override
  Future<NativeAuthResult> password(String identifier, String password) {
    final attempt = _restart();
    attempt.method = identifier.contains('@')
        ? LastLoginMethod.email
        : LastLoginMethod.phone;
    return _run(attempt, () async {
      await _wait(_sdk.cancel(), attempt);
      final configuration = await _wait(config(), attempt);
      if (_legacy) {
        final email = identifier.trim();
        final session = await _wait(
          _legacyCreateEmail == email.toLowerCase()
              ? _old.register(email: email, password: password)
              : _old.signIn(email: email, password: password),
          attempt,
        );
        return _remember(
          NativeAuthResult(
            status: NativeAuthStatus.authenticated,
            session: session,
          ),
          attempt,
        );
      }
      if (!configuration.allows('password') &&
          !configuration.allows('email_password') &&
          !configuration.allows('phone_password')) {
        throw _unavailable;
      }
      return _result(
        await _post('password', attempt, {
          'identifier': identifier.trim(),
          'password': password,
        }),
        attempt,
      );
    });
  }

  @override
  Future<NativeAuthResult> preparePhone(String phone, {String? ticket}) {
    final continuation = ticket == null
        ? null
        : _requireTicket(ticket, NativeAuthStatus.registrationRequired);
    final attempt = continuation?.attempt ?? _restart();
    attempt.method ??= LastLoginMethod.phone;
    return _run(attempt, () async {
      final configuration = await _wait(config(), attempt);
      if (!configuration.supportsUnverifiedPhoneEnrollment) throw _unavailable;
      return _continuationResult('phone/enroll', attempt, {
        'phone': phone,
        'ticket': ?ticket,
      });
    });
  }

  @override
  Future<NativeAuthResult> confirmUnverifiedPhone(
    String ticket,
    String phone,
  ) => _continue(
    ticket,
    NativeAuthStatus.registrationRequired,
    'phone/confirm',
    {'phone': phone},
  );

  @override
  Future<NativeOtpChallenge> sendOtp(
    String phone, {
    NativeOtpChallenge? resend,
    String? ticket,
  }) {
    final prior = resend?.handle;
    final continuation = ticket?.isNotEmpty == true
        ? _requireTicket(ticket!, NativeAuthStatus.registrationRequired)
        : null;
    if (resend != null &&
        (prior is! _PhoneOperation ||
            !identical(prior, _phone) ||
            prior.phone != phone)) {
      return Future.error(_cancelled);
    }
    final attempt = continuation != null || resend != null
        ? _attempt
        : _restart();
    attempt.method ??= LastLoginMethod.phone;
    final boundTicket =
        continuation?.result.ticket ??
        (prior is _PhoneOperation ? prior.ticket : null);
    _phone = null; // Late automatic events from the previous SMS cannot submit.
    return _run(attempt, () async {
      final configuration = await _wait(config(), attempt);
      if (_legacy || !configuration.allows('phone_otp')) throw _unavailable;
      final sdkChallenge = await _wait(
        _sdk.startPhone(
          config: _sdkConfig(configuration),
          phone: phone,
          resendToken: resend?.resendToken,
        ),
        attempt,
      );
      final operation = _PhoneOperation(
        attempt,
        sdkChallenge,
        phone,
        boundTicket,
      );
      _phone = operation;
      final automatic = sdkChallenge.automaticIdToken
          .then<NativeAuthResult?>((token) async {
            if (token == null) return null;
            _checkPhone(operation);
            return _settlePhone(operation, () async => token);
          })
          .catchError((Object error) => throw _safe(error));
      // Register a sink immediately, preserving the original observable future.
      unawaited(automatic.then<void>((_) {}, onError: (_, _) {}));
      return NativeOtpChallenge(
        phone: phone,
        handle: operation,
        resendToken: sdkChallenge.resendToken,
        automaticResult: automatic,
      );
    });
  }

  void _checkPhone(_PhoneOperation operation) {
    _active(operation.attempt);
    if (!identical(_phone, operation)) throw _cancelled;
  }

  @override
  Future<NativeAuthResult> verifyOtp(
    NativeOtpChallenge challenge,
    String code, {
    String? ticket,
  }) {
    final operation = challenge.handle;
    if (operation is! _PhoneOperation ||
        operation.phone != challenge.phone ||
        (ticket != null && ticket != operation.ticket)) {
      return Future.error(_cancelled);
    }
    try {
      _checkPhone(operation);
      return _settlePhone(operation, () async {
        try {
          return await _sdk.verifyPhone(operation.sdk, code);
        } on NativeAuthSdkException catch (error) {
          if (error.code != 'verification-in-progress') rethrow;
          final token = await operation.sdk.automaticIdToken;
          if (token == null) rethrow;
          return token;
        }
      });
    } catch (error) {
      return Future.error(_safe(error));
    }
  }

  Future<NativeAuthResult> _settlePhone(
    _PhoneOperation operation,
    Future<String> Function() proof,
  ) {
    _checkPhone(operation);
    if (operation.submission != null) return operation.submission!;
    final completer = Completer<NativeAuthResult>();
    operation.submission = completer.future;
    unawaited(
      _run(operation.attempt, () async {
        final token = await _wait(proof(), operation.attempt);
        _checkPhone(operation);
        if (token.isEmpty) throw const FormatException('Missing native proof.');
        if (operation.ticket != null) {
          _requireTicket(
            operation.ticket!,
            NativeAuthStatus.registrationRequired,
          );
        }
        final result =
            await _continuationResult('phone/verify', operation.attempt, {
              'phone': operation.phone,
              'id_token': token,
              if (operation.ticket != null) 'ticket': operation.ticket,
            });
        _checkPhone(operation);
        return result;
      }).then(
        completer.complete,
        onError: (Object error, StackTrace stack) {
          // An invalid SMS code is retryable; a submitted proof is shared by both paths.
          if (error is AuthRepositoryException &&
              error.code == 'invalid-verification-code') {
            operation.submission = null;
          }
          completer.completeError(error, stack);
        },
      ),
    );
    return completer.future;
  }

  @override
  Future<NativeAuthResult> google() => _google();

  @override
  Future<NativeAuthResult> facebook() {
    final attempt = _restart();
    attempt.method = LastLoginMethod.facebook;
    return _run(attempt, () async {
      await _wait(_sdk.cancel(), attempt);
      final configuration = await _wait(config(), attempt);
      final sdk = _sdk;
      if (_legacy ||
          !configuration.allows('facebook_native') ||
          sdk is! NativeFacebookAuthSdk) {
        throw _unavailable;
      }
      final challenge = await _post('facebook/challenge', attempt, {});
      final ticket = challenge['ticket'];
      final nonce = challenge['nonce'];
      final ttl = challenge['expires_in'];
      if (ticket is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(ticket) ||
          nonce is! String ||
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(nonce) ||
          ttl is! int ||
          ttl <= 0 ||
          ttl > 300) {
        throw const FormatException('Invalid Facebook challenge.');
      }
      final proof = await _wait(
        (sdk as NativeFacebookAuthSdk).facebook(
          _sdkConfig(configuration),
          nonce: nonce,
        ),
        attempt,
      );
      if (proof.token.isEmpty || (proof.limited && _platform != 'ios')) {
        throw const FormatException('Invalid Facebook proof.');
      }
      return _result(
        await _post('facebook', attempt, {
          'ticket': ticket,
          if (proof.limited)
            'id_token': proof.token
          else
            'access_token': proof.token,
        }),
        attempt,
      );
    });
  }

  @override
  Future<NativeAuthResult> apple() {
    final attempt = _restart();
    attempt.method = LastLoginMethod.apple;
    return _run(attempt, () async {
      await _wait(_sdk.cancel(), attempt);
      final configuration = await _wait(config(), attempt);
      final sdk = _sdk;
      if (_legacy ||
          _platform != 'ios' ||
          !configuration.allows('apple') ||
          sdk is! NativeAppleAuthSdk) {
        throw _unavailable;
      }
      final proof = await _wait(
        (sdk as NativeAppleAuthSdk).apple(_sdkConfig(configuration)),
        attempt,
      );
      if (proof.idToken.isEmpty) {
        throw const FormatException('Missing native proof.');
      }
      return _result(
        await _post('apple', attempt, {
          'id_token': proof.idToken,
          'name': proof.name,
        }),
        attempt,
      );
    });
  }

  @override
  Future<NativeAuthResult> googleForPhone(String expectedPhone) =>
      _google(expectedPhone: expectedPhone);

  Future<NativeAuthResult> _google({String? expectedPhone}) {
    final attempt = _restart();
    attempt.method = LastLoginMethod.google;
    return _run(attempt, () async {
      await _wait(_sdk.cancel(), attempt);
      final configuration = await _wait(config(), attempt);
      if (_legacy || !configuration.allows('google')) throw _unavailable;
      if (expectedPhone != null && !configuration.supportsExpectedPhoneGoogle) {
        throw _unavailable;
      }
      final token = await _wait(
        _sdk.google(_sdkConfig(configuration)),
        attempt,
      );
      if (token.isEmpty) throw const FormatException('Missing native proof.');
      return _result(
        await _post('google', attempt, {
          'id_token': token,
          'expected_phone': ?expectedPhone,
        }),
        attempt,
      );
    });
  }

  _Continuation _requireTicket(String ticket, NativeAuthStatus status) {
    final value = _continuation;
    if (value == null ||
        value.result.ticket != ticket ||
        value.result.status != status ||
        !value.expires.isAfter(DateTime.now())) {
      throw _expired;
    }
    _active(value.attempt);
    return value;
  }

  Future<NativeAuthResult> _continue(
    String ticket,
    NativeAuthStatus status,
    String action,
    Map<String, dynamic> body,
  ) {
    try {
      final continuation = _requireTicket(ticket, status);
      if (action == 'select' &&
          !continuation.result.accounts.any(
            (item) => item.id == body['account_id'],
          )) {
        throw _expired;
      }
      return _ticketRequests.putIfAbsent(ticket, () {
        final future = _run(
          continuation.attempt,
          () => _continuationResult(action, continuation.attempt, {
            'ticket': ticket,
            ...body,
          }),
        );
        unawaited(
          future.then<void>(
            (_) {},
            onError: (Object error, StackTrace _) {
              if (error is AuthRepositoryException &&
                  (error.statusCode == 400 ||
                      error.statusCode == 422 ||
                      error.statusCode == 429 ||
                      (error.statusCode == 409 &&
                          error.code == 'mobishop_native_retry'))) {
                _ticketRequests.remove(ticket);
              }
            },
          ),
        );
        return future;
      });
    } catch (error) {
      return Future.error(_safe(error));
    }
  }

  @override
  Future<NativeAuthResult> selectAccount(String ticket, int accountId) =>
      _continue(ticket, NativeAuthStatus.selectAccount, 'select', {
        'account_id': accountId,
      });

  Future<NativeAuthResult> _continuationResult(
    String action,
    _Attempt attempt,
    Map<String, dynamic> body,
  ) async {
    try {
      return _result(await _post(action, attempt, body), attempt);
    } catch (error) {
      final failure = _safe(error);
      if (const {
        AuthFailureKind.connection,
        AuthFailureKind.timeout,
        AuthFailureKind.server,
        AuthFailureKind.invalidResponse,
      }.contains(failure.kind)) {
        // A one-use request may have completed before its reply was lost.
        // Preserve deduplication and require a new independent sign-in attempt.
        throw AuthRepositoryException(
          kind: failure.kind,
          statusCode: failure.statusCode,
          code: 'continuation_restart_required',
          message: 'تعذر تأكيد نتيجة المحاولة. ابدأ تسجيل الدخول من جديد.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<NativeAuthResult> register(
    String ticket, {
    required String name,
    required String password,
    String? email,
  }) => _continue(ticket, NativeAuthStatus.registrationRequired, 'register', {
    'name': name,
    'password': password,
    if (email?.isNotEmpty == true) 'email': email,
  });

  NativeAuthResult _result(Map<String, dynamic> json, _Attempt attempt) =>
      _remember(NativeAuthResult.fromJson(json), attempt);

  NativeAuthResult _remember(NativeAuthResult result, _Attempt attempt) {
    _active(attempt);
    if (result.status == NativeAuthStatus.authenticated) {
      final session = result.session;
      if (session == null ||
          session.isExpired ||
          session.token.isEmpty ||
          session.token.length > 512 ||
          RegExp(r'[\x00-\x20\x7f]').hasMatch(session.token)) {
        throw const FormatException('Invalid session.');
      }
      _continuation = null;
    } else {
      _continuation = _Continuation(
        result,
        attempt,
        DateTime.now().add(Duration(seconds: result.expiresIn)),
      );
    }
    _owners[result] = attempt;
    return result;
  }

  @override
  Future<AuthSession> commit(NativeAuthResult result) {
    try {
      final owner = _owners[result];
      if (owner == null) throw _cancelled;
      _active(owner);
      final existing = _commits[result];
      if (existing != null) return existing;
      final session = result.session;
      if (result.status != NativeAuthStatus.authenticated ||
          session == null ||
          session.isExpired) {
        throw _expired;
      }
      // Storage commit is the linearization point. Closing afterwards does not revoke it.
      final future = _sessions
          .write(session)
          .then((_) async {
            final method = owner.method;
            if (method != null) {
              unawaited(
                Future<void>.sync(
                  () => _rememberMethod(method),
                ).catchError((Object _) {}),
              );
            }
            try {
              await _onCommitted?.call(session);
            } catch (_) {
              // UI/analytics failure cannot roll back an already stored session.
            }
            return session;
          })
          .catchError((Object error) {
            // Retrying the same storage value is safe and does not repeat proof exchange.
            _commits[result] = null;
            throw _safe(error);
          });
      _commits[result] = future;
      return future;
    } catch (error) {
      return Future.error(_safe(error));
    }
  }

  @override
  Future<void> cancel() async {
    _restart();
    _legacyCreateEmail = null;
    try {
      await _sdk.cancel();
    } catch (_) {
      /* Cancellation never alters a committed merchant session. */
    }
  }

  Map<String, dynamic> _sdkConfig(NativeAuthConfig value) => {
    'firebase': value.firebase,
    'google': value.google,
    'facebook': value.facebook,
  };

  Future<Map<String, dynamic>> _post(
    String action,
    _Attempt attempt,
    Map<String, dynamic> body,
  ) => _wait(
    _request(
      action,
      body: {
        'platform': _platform,
        if (_platform == 'ios') 'ios_phone_callback_version': 1,
        'verifier': attempt.verifier,
        ...body,
      },
    ),
    attempt,
  );

  Future<Map<String, dynamic>> _request(
    String action, {
    String method = 'POST',
    Map<String, dynamic>? body,
  }) async {
    if (!{
      'config',
      'identify',
      'password',
      'phone/verify',
      'phone/enroll',
      'phone/confirm',
      'google',
      'apple',
      'facebook/challenge',
      'facebook',
      'select',
      'register',
    }.contains(action)) {
      throw _unavailable;
    }
    final path = _store.path.replaceFirst(RegExp(r'/+$'), '');
    final uri = _store.replace(
      path: '$path/wp-json/mobishop/v1/auth/native/$action',
      queryParameters: method == 'GET'
          ? {
              'platform': _platform,
              if (_platform == 'ios') 'ios_phone_callback_version': '1',
            }
          : null,
    );
    try {
      final response = await _dio.requestUri<Object?>(
        uri,
        data: body,
        options: Options(
          method: method,
          responseType: ResponseType.json,
          followRedirects: false,
          maxRedirects: 0,
          validateStatus: (_) => true,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        ),
      );
      _checkOrigin(response.realUri);
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) {
        throw _httpError(status, response.data);
      }
      final value = response.data is String
          ? jsonDecode(response.data as String)
          : response.data;
      if (value is! Map) throw const FormatException('Invalid response.');
      return Map<String, dynamic>.from(value);
    } on DioException catch (error) {
      if (error.response != null) {
        _checkOrigin(error.response!.realUri);
        throw _httpError(error.response!.statusCode ?? 0, error.response!.data);
      }
      throw _safe(error);
    }
  }

  void _checkOrigin(Uri value) {
    if (value.scheme != 'https' ||
        value.userInfo.isNotEmpty ||
        value.origin != _store.origin) {
      throw const AuthRepositoryException(
        kind: AuthFailureKind.invalidResponse,
        message: 'تعذر التأكد من اتصال المتجر الآمن.',
      );
    }
  }

  static Uri _validateStore(Uri value) {
    if (value.scheme != 'https' ||
        value.host.isEmpty ||
        value.userInfo.isNotEmpty ||
        value.hasQuery ||
        value.hasFragment ||
        value.pathSegments.any((part) => part == '.' || part == '..')) {
      throw const AuthRepositoryException(
        kind: AuthFailureKind.configuration,
        message: 'عنوان المتجر الآمن غير مكتمل.',
      );
    }
    return value.replace(host: value.host.toLowerCase());
  }

  static const _cancelled = AuthRepositoryException(
    kind: AuthFailureKind.unknown,
    message: 'تم إلغاء محاولة الدخول.',
    code: 'cancelled',
  );
  static const _expired = AuthRepositoryException(
    kind: AuthFailureKind.unauthorized,
    message: 'انتهت محاولة الدخول. ابدأ من جديد.',
    code: 'expired',
  );
  static const _unavailable = AuthRepositoryException(
    kind: AuthFailureKind.configuration,
    message: 'طريقة الدخول دي غير متاحة حاليًا.',
    code: 'unavailable',
  );

  static AuthRepositoryException _httpError(int status, [Object? body]) {
    // Only translate known connector codes; never display arbitrary server text.
    Object? value = body;
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        value = null;
      }
    }
    final code = value is Map ? value['code'] : null;
    const messages = {
      'mobishop_native_retry':
          'في محاولة تانية بتكمل دلوقتي. انتظر قليلًا وحاول تاني.',
      'mobishop_native_google_phone_mismatch':
          'حساب جوجل ده مش مرتبط بالحساب المطلوب. جرّب حساب جوجل تاني أو الباسورد.',
      'mobishop_native_existing_phone':
          'الرقم ده لحساب موجود. ادخل بباسورد الحساب أو استخدم رقم مختلف.',
      'mobishop_native_phone_proof_required':
          'الحساب الموجود محتاج التحقق من رقم الموبايل.',
      'mobishop_native_phone_mismatch':
          'اكتب نفس رقم الموبايل اللي حاولنا نبعت له الرمز.',
      'mobishop_native_invalid_proof':
          'تعذر التحقق من محاولة الدخول. اختار الحساب وحاول تاني، أو استخدم كلمة المرور.',
      'mobishop_native_invalid_ticket': 'انتهت محاولة الدخول. ابدأ من جديد.',
      'mobishop_native_additional_proof_required':
          'الحساب ده محتاج تأكيد إضافي. استخدم كلمة مرور حساب المتجر أو رقم الموبايل.',
      'mobishop_native_account_conflict':
          'تعذر ربط الحساب بالطريقة دي. استخدم طريقة الدخول المعتادة للحساب.',
      'mobishop_native_phone_account_conflict':
          'الرقم ده مرتبط بحساب ماينفعش تكمل تسجيله بالطريقة دي. استخدم طريقة دخوله الأصلية أو رقم مختلف.',
      'mobishop_native_account_deletion_pending':
          'حذف الحساب لسه بيتم. بعد اكتمال الحذف تقدر تسجّل حساب جديد.',
      'mobishop_auth_account_deletion_pending':
          'حذف الحساب لسه بيتم. بعد اكتمال الحذف تقدر تسجّل حساب جديد.',
      'mobishop_native_unavailable':
          'طريقة الدخول دي غير متاحة حاليًا. اختار طريقة تانية.',
    };
    return AuthRepositoryException(
      kind: switch (status) {
        400 || 422 => AuthFailureKind.invalidInput,
        401 || 403 => AuthFailureKind.unauthorized,
        409 => AuthFailureKind.conflict,
        429 => AuthFailureKind.rateLimited,
        >= 500 => AuthFailureKind.server,
        _ => AuthFailureKind.invalidResponse,
      },
      statusCode: status,
      code: messages.containsKey(code) ? code as String : null,
      message:
          messages[code] ??
          switch (status) {
            400 || 422 => 'راجع البيانات وحاول تاني.',
            401 || 403 => 'تعذر تأكيد بيانات الدخول.',
            409 => 'تعذر ربط الحساب. ابدأ محاولة جديدة.',
            429 => 'محاولات كتير. انتظر قليلًا وحاول تاني.',
            _ => 'تعذر الاتصال بالمتجر. حاول تاني.',
          },
    );
  }

  static AuthRepositoryException _safe(Object error) {
    if (error is AuthRepositoryException) return error;
    if (error is AuthApiException) {
      return AuthRepositoryException(
        kind: error.kind,
        statusCode: error.statusCode,
        code: error.code,
        message: 'تعذر إكمال تسجيل الدخول. راجع البيانات وحاول تاني.',
      );
    }
    if (error is NativeAuthSdkException) {
      return AuthRepositoryException(
        kind: switch (error.code) {
          'too-many-requests' ||
          'quota-exceeded' => AuthFailureKind.rateLimited,
          'network-request-failed' => AuthFailureKind.connection,
          _ => AuthFailureKind.invalidInput,
        },
        code: error.code,
        message: switch (error.code) {
          'invalid-verification-code' => 'رمز التأكيد غير صحيح. جرّب تاني.',
          'session-expired' || 'code-expired' =>
            'انتهت صلاحية رمز التحقق. اطلب رمز جديد أو اختار طريقة دخول تانية.',
          'invalid-phone-number' => 'راجع رقم الموبايل وكود الدولة وحاول تاني.',
          'network-request-failed' =>
            'الاتصال انقطع أثناء التحقق. راجع الإنترنت وحاول تاني.',
          'too-many-requests' || 'quota-exceeded' =>
            'إرسال الرموز متوقف مؤقتًا. انتظر قليلًا أو استخدم طريقة دخول تانية.',
          'app-not-authorized' ||
          'invalid-app-credential' ||
          'missing-client-identifier' ||
          'operation-not-allowed' ||
          'captcha-check-failed' =>
            'تعذر تفعيل التحقق على النسخة دي. استخدم كلمة المرور أو جوجل مؤقتًا.',
          'google-not-configured' ||
          'google-native-registration-required' ||
          'google-clientConfigurationError' =>
            'الدخول بجوجل غير جاهز في النسخة دي. استخدم طريقة دخول تانية.',
          _ => 'تعذر إكمال التحقق. اختار طريقة دخول تانية أو حاول مرة أخرى.',
        },
      );
    }
    if (error is DioException) {
      return AuthRepositoryException(
        kind: switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.transformTimeout => AuthFailureKind.timeout,
          DioExceptionType.badCertificate => AuthFailureKind.certificate,
          _ => AuthFailureKind.connection,
        },
        message: switch (error.type) {
          DioExceptionType.connectionTimeout ||
          DioExceptionType.sendTimeout ||
          DioExceptionType.receiveTimeout ||
          DioExceptionType.transformTimeout =>
            'الاتصال بالمتجر أخد وقت أطول من المتوقع. راجع الإنترنت وحاول تاني.',
          DioExceptionType.badCertificate =>
            'تعذر التحقق من شهادة أمان المتجر. حاول لاحقًا أو تواصل مع الدعم.',
          _ => 'تعذر الاتصال بالمتجر. راجع الإنترنت وحاول تاني.',
        },
      );
    }
    return const AuthRepositoryException(
      kind: AuthFailureKind.invalidResponse,
      message: 'تعذر إكمال تسجيل الدخول. حاول تاني.',
    );
  }
}

class _Attempt {
  LastLoginMethod? method;
  final verifier = List.generate(
    32,
    (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
  final cancelled = Completer<void>();
  void cancel() {
    if (!cancelled.isCompleted) cancelled.complete();
  }
}

class _PhoneOperation {
  _PhoneOperation(this.attempt, this.sdk, this.phone, this.ticket);
  final _Attempt attempt;
  final NativePhoneChallenge sdk;
  final String phone;
  final String? ticket;
  Future<NativeAuthResult>? submission;
}

class _Continuation {
  _Continuation(this.result, this.attempt, this.expires);
  final NativeAuthResult result;
  final _Attempt attempt;
  final DateTime expires;
}
