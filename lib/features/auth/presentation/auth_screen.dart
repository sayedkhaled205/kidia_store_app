import 'dart:async';
import 'package:mobishop_store_app/core/app_design/store_privacy_provider.dart';
import '../../account/presentation/store_privacy_link.dart';
import '../../account/application/account_deletion_recovery.dart';
import '../data/storage/last_login_method_store.dart';
import 'package:mobishop_store_app/features/auth/data/cms_preview_auth_actions.dart';
import 'package:mobishop_store_app/features/auth/data/website_auth_service.dart';
import 'package:mobishop_store_app/core/app_design/app_ui_controls.dart';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mobishop_store_app/core/app_design/application_identity_provider58.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/theme/mobishop_colors.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/native_auth.dart';
import 'package:mobishop_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobishop_store_app/features/auth/presentation/auth_copy.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/native_auth_providers.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/shared/widgets/common/app_network_image.dart';

enum _AuthStep {
  identifier,
  method,
  recovery,
  password,
  createPassword,
  otp,
  accounts,
  registration,
  phone,
}

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.popOnSuccess = true});

  /// Protected screens retain their full route while the session changes.
  final bool popOnSuccess;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  AppUiControls get _ui => AppUiControlsScope.of(context);
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _otp = TextEditingController();
  final _name = TextEditingController();
  bool _registrationDetailsCollected = false;
  bool _restartRequired = false;
  final _email = TextEditingController();
  final _phone = TextEditingController();
  NativeAuthActions? _actions;
  WebsiteAuthAttempt? _websiteAttempt;
  NativeAuthIdentity? _identity;
  NativeAuthResult? _continuation;
  NativeAuthResult? _pendingCommit;
  NativeOtpChallenge? _challenge;
  String? _otpTicket;
  String? _recoveryPhone;
  bool _canRetryCode = false;
  bool _confirmContactPhone = false;
  bool _existingContactPhone = false;
  bool _existingOtpSendFailed = false;
  _AuthStep _step = _AuthStep.identifier;
  bool _busy = false;
  bool _resolving = false;
  bool _closing = false;
  bool _completed = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _error;
  int _flow = 0;
  int _operation = 0;
  int _otpEpoch = 0;
  int _resendSeconds = 0;
  Timer? _resendTimer;

  bool _active(int flow) => mounted && !_closing && flow == _flow;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(accountDeletionRecoveryProvider);
    });
    // A failed background prefetch must not strand a newly opened sign-in page.
    if (ref.read(nativeAuthConfigProvider).hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(nativeAuthConfigProvider);
      });
    }
  }

  @override
  void dispose() {
    _flow++;
    _otpEpoch++;
    _resendTimer?.cancel();
    if (!_completed) _cancelActions();
    for (final controller in [
      _identifier,
      _password,
      _confirmation,
      _otp,
      _name,
      _email,
      _phone,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _cancelActions() {
    _websiteAttempt?.cancel();
    final actions = _actions;
    if (actions != null) unawaited(actions.cancel().catchError((Object _) {}));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(accountDeletionRecoveryProvider);
    ref.watch(authControllerProvider);
    _actions = ref.watch(nativeAuthActionsProvider);
    final configState = ref.watch(nativeAuthConfigProvider);
    final config = configState.value;
    final hasIdentifier =
        config?.supportsPhone == true ||
        config?.allows('email_password') == true;
    final showGoogle =
        [
          _AuthStep.identifier,
          _AuthStep.method,
          _AuthStep.password,
          _AuthStep.recovery,
        ].contains(_step) &&
        config?.allows('google') == true &&
        (_expectedGooglePhone == null ||
            (config!.supportsExpectedPhoneGoogle &&
                _actions is NativeExistingPhoneGoogleActions));
    final showFacebook =
        [_AuthStep.identifier, _AuthStep.password].contains(_step) &&
        _expectedGooglePhone == null &&
        (config?.allows('facebook') == true ||
            config?.allows('facebook_native') == true);
    final showApple =
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        [_AuthStep.identifier, _AuthStep.password].contains(_step) &&
        _expectedGooglePhone == null &&
        config?.allows('apple') == true &&
        _actions is NativeAppleAuthActions;
    final copy = AuthCopy.of(context);
    final lastLogin = ref.watch(lastLoginMethodProvider).value;
    final branding = ref.watch(applicationIdentity58Provider);
    final storeName = branding?['app_name'] as String? ?? AppConfig.storeName;
    final logo =
        ref
            .watch(cmsPageLayoutProvider('account'))
            .value
            ?.header
            .string('logo_url', '') ??
        '';
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && !_completed) {
          _closing = true;
          _flow++;
          _cancelActions();
        }
      },
      child: Scaffold(
        backgroundColor: _ui.color('auth_background'),
        appBar: AppBar(
          backgroundColor: _ui.color('auth_background'),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: IconButton(
            key: const Key('auth-close'),
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            onPressed: _close,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                _ui.number('auth_side_padding'),
                _ui.number('auth_top_spacing'),
                _ui.number('auth_side_padding'),
                24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StoreMark(
                          storeName: storeName,
                          logoUrl: logo,
                          scale:
                              ref
                                  .watch(cmsPageLayoutProvider('account'))
                                  .value
                                  ?.header
                                  .number('auth_logo_scale', 1) ??
                              1,
                          aspectRatio:
                              ref
                                  .watch(cmsPageLayoutProvider('account'))
                                  .value
                                  ?.header
                                  .number('logo_aspect_ratio', 0) ??
                              0,
                        ),
                        SizedBox(height: _ui.number('auth_logo_gap')),
                        Text(
                          _title(copy),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontSize: _ui.number('auth_title_size'),
                                fontWeight: FontWeight.w700,
                                color: _ui.color('auth_title_color'),
                              ),
                        ),
                        const SizedBox(height: 8),
                        if (_step == _AuthStep.identifier)
                          Text(
                            config?.supportsPhone == true
                                ? copy.identifierIntro
                                : (hasIdentifier
                                      ? copy.intro
                                      : copy.chooseMethod),
                            textAlign: TextAlign.center,
                            style: _secondaryStyle,
                          )
                        else
                          ..._identitySummary(copy),
                        const SizedBox(height: 24),
                        if (configState.isLoading && config == null)
                          const Center(
                            child: CircularProgressIndicator(
                              key: Key('auth-config-loading'),
                            ),
                          )
                        else if (configState.hasError ||
                            config == null ||
                            !config.enabled)
                          Column(
                            children: [
                              Text(
                                copy.unavailable,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                key: const Key('auth-config-retry'),
                                onPressed: () =>
                                    ref.invalidate(nativeAuthConfigProvider),
                                child: Text(copy.retry),
                              ),
                            ],
                          )
                        else ...[
                          if (!_restartRequired) ..._fields(copy, config),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                _error!,
                                key: const Key('auth-error'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                          if (_restartRequired)
                            _primaryButton(
                              key: const Key('auth-restart'),
                              label: copy.restartSignIn,
                              onPressed: _changeIdentifier,
                            ),
                          if (!_restartRequired &&
                              _hasSubmit &&
                              (_step != _AuthStep.identifier ||
                                  hasIdentifier)) ...[
                            const SizedBox(height: 20),
                            _primaryButton(
                              key: Key(_submitKey),
                              label: _submitLabel(copy),
                              onPressed: () => _submit(copy, config),
                            ),
                            if (_step == _AuthStep.identifier &&
                                ((lastLogin == LastLoginMethod.phone &&
                                        config.supportsPhone) ||
                                    (lastLogin == LastLoginMethod.email &&
                                        config.allows('email_password'))))
                              _lastLoginBadge(
                                '${copy.lastLogin} · ${lastLogin == LastLoginMethod.phone ? (copy.isArabic ? 'الموبايل' : 'Phone') : (copy.isArabic ? 'الإيميل' : 'Email')}',
                              ),
                          ],
                          if (_step == _AuthStep.password &&
                              !_existingOtpSendFailed &&
                              config.allows('phone_otp') &&
                              _identity?.allows('phone_otp') == true)
                            TextButton(
                              key: const Key('auth-use-otp'),
                              onPressed: _busy
                                  ? null
                                  : () => _perform(
                                      (flow) =>
                                          _sendOtp(flow, _identity!.identifier),
                                    ),
                              child: Text(copy.useOtp),
                            ),
                          if ([
                                _AuthStep.method,
                                _AuthStep.password,
                                _AuthStep.recovery,
                              ].contains(_step) &&
                              _identity?.requiresEmailRegistration != true &&
                              config.passwordResetUri != null)
                            TextButton(
                              key: const Key('auth-forgot-password'),
                              onPressed: _busy
                                  ? null
                                  : () => _perform((flow) async {
                                      final opened = await launchUrl(
                                        config.passwordResetUri!,
                                        mode: LaunchMode.externalApplication,
                                      );
                                      if (!opened && _active(flow)) {
                                        throw StateError(
                                          'Password recovery did not open.',
                                        );
                                      }
                                    }),
                              child: Text(copy.forgotPassword),
                            ),
                          if (_step == _AuthStep.otp)
                            TextButton(
                              key: const Key('auth-resend'),
                              onPressed:
                                  _busy ||
                                      _resendSeconds > 0 ||
                                      _challenge == null
                                  ? null
                                  : () => _perform(
                                      (flow) => _sendOtp(
                                        flow,
                                        _challenge!.phone,
                                        previous: _challenge,
                                        ticket: _otpTicket,
                                      ),
                                    ),
                              child: Text(
                                _resendSeconds > 0
                                    ? '${copy.resendOtp} ($_resendSeconds)'
                                    : copy.resendOtp,
                              ),
                            ),
                          if (showGoogle || showFacebook || showApple) ...[
                            if (hasIdentifier) ...[
                              const SizedBox(height: 28),
                              Center(
                                child: SizedBox(
                                  width: 176,
                                  child: Row(
                                    key: const Key('auth-social-or'),
                                    children: [
                                      const Expanded(
                                        child: Divider(
                                          color: Color(0xFFE5E5E5),
                                          endIndent: 18,
                                        ),
                                      ),
                                      Text(copy.or, style: _secondaryStyle),
                                      const Expanded(
                                        child: Divider(
                                          color: Color(0xFFE5E5E5),
                                          indent: 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              textDirection: TextDirection.ltr,
                              children: [
                                if (showApple) ...[
                                  _loginOption(
                                    last: lastLogin == LastLoginMethod.apple,
                                    copy: copy,
                                    child: Tooltip(
                                      message: copy.continueWithApple,
                                      child: OutlinedButton(
                                        key: const Key('auth-apple'),
                                        onPressed: _busy
                                            ? null
                                            : () => _perform((flow) async {
                                                _otpEpoch++;
                                                setState(() {
                                                  _challenge = null;
                                                  _otpTicket = null;
                                                  _continuation = null;
                                                  _canRetryCode = false;
                                                });
                                                _registrationDetailsCollected =
                                                    false;
                                                final result =
                                                    await (_actions
                                                            as NativeAppleAuthActions)
                                                        .apple();
                                                if (_active(flow)) {
                                                  _identity = null;
                                                  await _acceptResult(
                                                    result,
                                                    flow,
                                                  );
                                                }
                                              }),
                                        style: OutlinedButton.styleFrom(
                                          fixedSize: const Size.square(52),
                                          minimumSize: const Size.square(52),
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.standard,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          backgroundColor: Colors.black,
                                          foregroundColor: Colors.white,
                                          side: BorderSide.none,
                                          shape: const CircleBorder(),
                                        ),
                                        child: Semantics(
                                          label: copy.continueWithApple,
                                          child: const Icon(
                                            Icons.apple,
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (showGoogle || showFacebook)
                                    const SizedBox(width: 4),
                                ],
                                if (showGoogle)
                                  _loginOption(
                                    last: lastLogin == LastLoginMethod.google,
                                    copy: copy,
                                    child: Tooltip(
                                      message: copy.continueWithGoogle,
                                      excludeFromSemantics: true,
                                      child: OutlinedButton(
                                        key: const Key('auth-google'),
                                        onPressed: _busy
                                            ? null
                                            : () => _perform((flow) async {
                                                _otpEpoch++;
                                                // Google starts a new service attempt, so
                                                // the previous phone proof cannot be reused.
                                                setState(() {
                                                  _challenge = null;
                                                  _otpTicket = null;
                                                  _continuation = null;
                                                  _canRetryCode = false;
                                                });
                                                _registrationDetailsCollected =
                                                    false;
                                                final expectedPhone =
                                                    _expectedGooglePhone;
                                                final result =
                                                    expectedPhone == null
                                                    ? await _actions!.google()
                                                    : await (_actions
                                                              as NativeExistingPhoneGoogleActions)
                                                          .googleForPhone(
                                                            expectedPhone,
                                                          );
                                                if (_active(flow)) {
                                                  if (result.status ==
                                                      NativeAuthStatus
                                                          .registrationRequired) {
                                                    _identity = null;
                                                  }
                                                  await _acceptResult(
                                                    result,
                                                    flow,
                                                  );
                                                }
                                              }),
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.standard,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          fixedSize: Size.square(
                                            _ui.numberOr(
                                              'auth_google_button_height',
                                              52,
                                            ),
                                          ),
                                          minimumSize: Size.square(
                                            _ui.numberOr(
                                              'auth_google_button_height',
                                              52,
                                            ),
                                          ),
                                          padding: EdgeInsets.zero,
                                          backgroundColor: Colors.white,
                                          side: const BorderSide(
                                            color: Color(0xFFDADCE0),
                                            width: 1.5,
                                          ),
                                          shape: const CircleBorder(),
                                        ),
                                        child: Semantics(
                                          label: copy.continueWithGoogle,
                                          child: Image.asset(
                                            'assets/branding/google-g.png',
                                            key: const Key('auth-google-brand'),
                                            width: 28,
                                            height: 28,
                                            fit: BoxFit.contain,
                                            excludeFromSemantics: true,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (showGoogle && showFacebook)
                                  const SizedBox(width: 4),
                                if (showFacebook)
                                  _loginOption(
                                    last: lastLogin == LastLoginMethod.facebook,
                                    copy: copy,
                                    child: Tooltip(
                                      message: copy.continueWithFacebook,
                                      excludeFromSemantics: true,
                                      child: OutlinedButton(
                                        key: const Key('auth-facebook'),
                                        onPressed: _busy ? null : _facebook,
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.standard,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          fixedSize: const Size.square(52),
                                          minimumSize: const Size.square(52),
                                          padding: EdgeInsets.zero,
                                          side: BorderSide.none,
                                          shape: const CircleBorder(),
                                        ),
                                        child: Semantics(
                                          label: copy.continueWithFacebook,
                                          child: ExcludeSemantics(
                                            child: CustomPaint(
                                              key: const Key(
                                                'auth-facebook-brand',
                                              ),
                                              size: const Size.square(52),
                                              painter: _FacebookMark(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                        const SizedBox(height: 28),
                        Text(
                          copy.privacyPrefix,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: MobiShopColors.textSecondary),
                        ),
                        StorePrivacyLink(
                          policyUri: safeStorePrivacyUri(
                            config?.privacyPolicyUrl ?? '',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle? get _secondaryStyle => Theme.of(
    context,
  ).textTheme.bodyMedium?.copyWith(color: MobiShopColors.textSecondary);

  String _title(AuthCopy copy) => switch (_step) {
    _AuthStep.identifier => copy.title,
    _AuthStep.method =>
      _identity?.requiresEmailRegistration == true
          ? copy.createTitle
          : copy.chooseMethod,
    _AuthStep.recovery => copy.chooseAnotherMethod,
    _AuthStep.password => copy.existingTitle,
    _AuthStep.createPassword => copy.createTitle,
    _AuthStep.otp => copy.otpTitle,
    _AuthStep.accounts => copy.chooseAccount,
    _AuthStep.registration => copy.completeAccount,
    _AuthStep.phone =>
      _existingContactPhone ? copy.existingPhoneTitle : copy.verifyPhone,
  };

  List<Widget> _identitySummary(AuthCopy copy) {
    if (_existingContactPhone) return [];
    final value = _step == _AuthStep.otp
        ? _challenge?.phone ?? _phone.text
        : _identity?.identifier ?? _recoveryPhone ?? '';
    return [
      if (_step == _AuthStep.otp)
        Text(copy.otpSent, textAlign: TextAlign.center, style: _secondaryStyle),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (value.isNotEmpty)
            Flexible(
              child: Text(
                value,
                textDirection: TextDirection.ltr,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          TextButton(
            key: const Key('auth-change-email'),
            onPressed: _changeIdentifier,
            child: Text(copy.changeIdentifier),
          ),
        ],
      ),
    ];
  }

  List<Widget> _fields(AuthCopy copy, NativeAuthConfig config) {
    switch (_step) {
      case _AuthStep.identifier:
        if (!config.supportsPhone && !config.allows('email_password')) {
          return [];
        }
        return [
          _textField(
            key: const Key('auth-email'),
            controller: _identifier,
            hint: _ui.text(
              'auth_identifier_hint',
              copy.isArabic,
              config.supportsPhone ? config.phoneHint : '',
            ),
            label: config.supportsPhone
                ? (config.allows('email_password')
                      ? copy.identifier
                      : copy.phone)
                : copy.email,
            keyboard: config.supportsPhone
                ? TextInputType.text
                : TextInputType.emailAddress,
            autofill: AutofillHints.username,
            validator: (value) => _validIdentifier(value ?? '', config)
                ? null
                : (config.supportsPhone
                      ? copy.identifierRequired
                      : copy.emailRequired),
            onSubmitted: () => _submit(copy, config),
          ),
        ];
      case _AuthStep.method:
        return [
          if (_identity!.requiresEmailRegistration) ...[
            Text(
              copy.newPhoneIntro,
              textAlign: TextAlign.center,
              style: _secondaryStyle,
            ),
            const SizedBox(height: 20),
          ],
          if (_identity!.allows('email_password') &&
              config.allows('email_password'))
            _methodButton(
              key: const Key('auth-use-email'),
              label: _identity!.requiresEmailRegistration
                  ? copy.createWithEmail
                  : copy.useAccountEmail,
              icon: Icons.email_outlined,
              onPressed: () {
                _changeIdentifier();
                _identifier.clear();
              },
            ),
          if (_identity!.allows('password') && _phonePasswordEnabled(config))
            _methodButton(
              key: const Key('auth-use-password'),
              label: copy.usePassword,
              icon: Icons.password_rounded,
              onPressed: () => setState(() {
                _step = _AuthStep.password;
                _error = null;
              }),
            ),
          if (_identity!.allows('phone_otp') && config.allows('phone_otp')) ...[
            const SizedBox(height: 12),
            _methodButton(
              key: const Key('auth-use-otp'),
              label: copy.useOtp,
              icon: Icons.sms_outlined,
              onPressed: () =>
                  _perform((flow) => _sendOtp(flow, _identity!.identifier)),
            ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ];
      case _AuthStep.recovery:
        return [
          Text(
            _existingOtpSendFailed ? copy.otpSendFailed : copy.otpAlternatives,
            textAlign: TextAlign.center,
            style: _secondaryStyle,
          ),
          const SizedBox(height: 16),
          if ((_identity?.allows('password') == true || _identity == null) &&
              _phonePasswordEnabled(config))
            _methodButton(
              key: const Key('auth-use-password'),
              label: copy.usePassword,
              icon: Icons.password_rounded,
              onPressed: () => _perform((flow) async {
                _otpEpoch++;
                await _actions!.cancel();
                if (!_active(flow)) return;
                final identity =
                    _identity ?? await _actions!.identify(_recoveryPhone!);
                if (!_active(flow)) return;
                if (!identity.allows('password')) {
                  throw StateError('Password is unavailable.');
                }
                setState(() {
                  _identity = identity;
                  _registrationDetailsCollected = false;
                  _continuation = null;
                  _challenge = null;
                  _otpTicket = null;
                  _password.clear();
                  _step = _AuthStep.password;
                });
              }),
            ),
          const SizedBox(height: 12),
          if (!_existingOtpSendFailed)
            TextButton(
              key: const Key('auth-retry-otp'),
              onPressed: _busy || (!_canRetryCode && _resendSeconds > 0)
                  ? null
                  : () {
                      if (_canRetryCode && _challenge != null) {
                        setState(() {
                          _otp.clear();
                          _error = null;
                          _step = _AuthStep.otp;
                        });
                      } else {
                        unawaited(
                          _perform(
                            (flow) => _sendOtp(
                              flow,
                              _recoveryPhone!,
                              ticket: _otpTicket,
                            ),
                          ),
                        );
                      }
                    },
              child: Text(
                _canRetryCode
                    ? copy.retryCode
                    : _resendSeconds > 0
                    ? '${copy.retryOtp} ($_resendSeconds)'
                    : copy.retryOtp,
              ),
            ),
          if (_busy) const Center(child: CircularProgressIndicator()),
        ];
      case _AuthStep.createPassword:
        return [
          _textField(
            key: const Key('auth-name'),
            controller: _name,
            label: copy.name,
            keyboard: TextInputType.name,
            autofill: AutofillHints.name,
            direction: null,
            validator: (value) =>
                value?.trim().isNotEmpty == true ? null : copy.nameRequired,
          ),
          const SizedBox(height: 14),
          ..._passwordFields(copy, creating: true),
        ];
      case _AuthStep.password:
        return _passwordFields(copy, creating: false);
      case _AuthStep.otp:
        return [
          _textField(
            key: const Key('auth-otp'),
            controller: _otp,
            label: copy.otpCode,
            keyboard: TextInputType.number,
            autofill: AutofillHints.oneTimeCode,
            formatter: FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹]')),
            maxLength: 6,
            validator: (value) =>
                RegExp(r'^\d{6}$').hasMatch(_digits(value ?? ''))
                ? null
                : copy.otpRequired,
            onSubmitted: () => _submit(copy, config),
          ),
        ];
      case _AuthStep.accounts:
        return [
          Text(
            copy.chooseAccountIntro,
            textAlign: TextAlign.center,
            style: _secondaryStyle,
          ),
          const SizedBox(height: 16),
          for (final account in _continuation!.accounts)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OutlinedButton(
                key: Key('auth-account-${account.id}'),
                onPressed: _busy
                    ? null
                    : () => _perform((flow) async {
                        final result = await _actions!.selectAccount(
                          _continuation!.ticket,
                          account.id,
                        );
                        if (_active(flow)) await _acceptResult(result, flow);
                      }),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(account.name),
                          if (account.emailHint.isNotEmpty)
                            Text(
                              account.emailHint,
                              textDirection: TextDirection.ltr,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_busy) const Center(child: CircularProgressIndicator()),
        ];
      case _AuthStep.phone:
        if (_existingContactPhone) {
          final colors = Theme.of(context).colorScheme;
          final phone = _recoveryPhone ?? _phone.text;
          final displayPhone =
              config.phoneCountryCode == '20' && phone.startsWith('+20')
              ? '0${phone.substring(3)}'
              : phone;
          return [
            Container(
              key: const Key('auth-existing-account-card'),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    color: colors.primary,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    copy.existingContactPhone,
                    textAlign: TextAlign.center,
                    style: _secondaryStyle?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayPhone,
                    key: const Key('auth-existing-account-phone'),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _primaryButton(
              key: const Key('auth-existing-phone-signin'),
              label: copy.enterExistingAccount,
              onPressed: () => _perform((flow) async {
                _otpEpoch++;
                final identity = await _actions!.identify(_recoveryPhone!);
                if (!_active(flow)) return;
                setState(() {
                  _identity = identity;
                  _registrationDetailsCollected = false;
                  _continuation = null;
                  _challenge = null;
                  _otpTicket = null;
                  _password.clear();
                  _confirmation.clear();
                  _otp.clear();
                  _name.clear();
                  _email.clear();
                  _pendingCommit = null;
                  _step = _AuthStep.method;
                  _existingContactPhone = false;
                  _confirmContactPhone = false;
                });
              }),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: const Key('auth-different-phone'),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      _existingContactPhone = false;
                      _confirmContactPhone = false;
                      _phone.clear();
                      _error = null;
                    }),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: Text(copy.differentPhone, textAlign: TextAlign.center),
            ),
          ];
        }
        return [
          Text(
            _confirmContactPhone
                ? copy.confirmContactPhone
                : copy.phoneRequiredForAccount,
            textAlign: TextAlign.center,
            style: _secondaryStyle,
          ),
          const SizedBox(height: 16),
          _textField(
            key: const Key('auth-phone'),
            controller: _phone,
            label: copy.phone,
            hint: config.phoneHint,
            keyboard: TextInputType.phone,
            autofill: AutofillHints.telephoneNumber,
            validator: (value) => config.normalizeOtpPhone(value ?? '') != null
                ? null
                : copy.phoneRequired,
            onSubmitted: () => _submit(copy, config),
          ),
        ];
      case _AuthStep.registration:
        final fields = _continuation!.fields;
        return [
          if (fields.contains('name')) ...[
            _textField(
              key: const Key('auth-name'),
              controller: _name,
              label: copy.name,
              keyboard: TextInputType.name,
              autofill: AutofillHints.name,
              direction: null,
              validator: (value) => (value?.trim().isNotEmpty ?? false)
                  ? null
                  : copy.nameRequired,
            ),
            const SizedBox(height: 14),
          ],
          if (fields.contains('email')) ...[
            _textField(
              key: const Key('auth-registration-email'),
              controller: _email,
              label: copy.optionalEmail,
              keyboard: TextInputType.emailAddress,
              autofill: AutofillHints.email,
              validator: (value) =>
                  value?.trim().isEmpty != false || _validEmail(value!)
                  ? null
                  : copy.emailRequired,
            ),
            const SizedBox(height: 14),
          ],
          if (fields.contains('password'))
            ..._passwordFields(copy, creating: true),
        ];
    }
  }

  List<Widget> _passwordFields(AuthCopy copy, {required bool creating}) => [
    _passwordField(
      key: Key(creating ? 'auth-create-password' : 'auth-password'),
      controller: _password,
      label: copy.password,
      obscure: _obscurePassword,
      onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
      creating: creating,
      validator: (value) => creating
          ? ((value ?? '').length < 8 ? copy.passwordTooShort : null)
          : (value?.isNotEmpty == true ? null : copy.passwordRequired),
    ),
    if (creating) ...[
      const SizedBox(height: 14),
      _passwordField(
        key: const Key('auth-confirm-password'),
        controller: _confirmation,
        label: copy.confirmPassword,
        obscure: _obscureConfirmation,
        creating: true,
        onToggle: () =>
            setState(() => _obscureConfirmation = !_obscureConfirmation),
        validator: (value) =>
            value == _password.text ? null : copy.passwordMismatch,
      ),
    ],
  ];

  Widget _textField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required TextInputType keyboard,
    required String autofill,
    required String? Function(String?) validator,
    VoidCallback? onSubmitted,
    TextInputFormatter? formatter,
    int? maxLength,
    String? hint,
    TextDirection? direction = TextDirection.ltr,
  }) {
    final field = TextFormField(
      key: key,
      controller: controller,
      enabled: !_busy,
      keyboardType: keyboard,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      autofillHints: [autofill],
      autocorrect: false,
      enableSuggestions: false,
      maxLength: maxLength,
      inputFormatters: formatter == null ? null : [formatter],
      decoration: _decoration(label).copyWith(
        counterText: '',
        hintText: hint?.isNotEmpty == true ? hint : label,
        labelText: hint?.isNotEmpty == true ? label : null,
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
        floatingLabelBehavior: hint?.isNotEmpty == true
            ? FloatingLabelBehavior.always
            : null,
      ),
      validator: validator,
      onFieldSubmitted: (_) {
        if (!_busy) onSubmitted?.call();
      },
    );
    return direction == null
        ? field
        : Directionality(textDirection: direction, child: field);
  }

  Widget _passwordField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required bool creating,
    required String? Function(String?) validator,
  }) => Directionality(
    textDirection: TextDirection.ltr,
    child: TextFormField(
      key: key,
      controller: controller,
      enabled: !_busy,
      obscureText: obscure,
      textInputAction: creating ? TextInputAction.next : TextInputAction.done,
      autofillHints: [
        creating ? AutofillHints.newPassword : AutofillHints.password,
      ],
      enableSuggestions: false,
      autocorrect: false,
      validator: validator,
      onFieldSubmitted: (_) {
        final config = ref.read(nativeAuthConfigProvider).value;
        if (!_busy && config != null) _submit(AuthCopy.of(context), config);
      },
      decoration: _decoration(label).copyWith(
        suffixIcon: IconButton(
          tooltip: obscure
              ? AuthCopy.of(context).showPassword
              : AuthCopy.of(context).hidePassword,
          onPressed: _busy ? null : onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
    ),
  );

  InputDecoration _decoration(String label) => InputDecoration(
    hintText: label,
    hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
    filled: false,
    contentPadding: EdgeInsets.symmetric(
      horizontal: 16,
      vertical: _ui.number('auth_field_padding'),
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_ui.number('auth_field_radius')),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_ui.number('auth_field_radius')),
      borderSide: const BorderSide(color: Color(0xFFD9DFE3)),
    ),
  );

  Widget _loginOption({
    required Widget child,
    required bool last,
    required AuthCopy copy,
  }) => SizedBox(
    width: 80,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        child,
        SizedBox(
          height: 34,
          child: last ? _lastLoginBadge(copy.lastLogin) : null,
        ),
      ],
    ),
  );

  Widget _lastLoginBadge(String label) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        height: 8,
        child: CustomPaint(
          size: const Size(12, 8),
          painter: _LoginHintPointer(),
        ),
      ),
      Container(
        key: const Key('auth-last-login'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        color: const Color(0xFF4A4A4A),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            height: 1.3,
          ),
        ),
      ),
    ],
  );

  Widget _primaryButton({
    required Key key,
    required String label,
    required VoidCallback onPressed,
  }) => FilledButton(
    key: key,
    style: FilledButton.styleFrom(
      minimumSize: Size.fromHeight(_ui.number('auth_button_height')),
      shape: const StadiumBorder(),
    ),
    onPressed: _busy ? null : onPressed,
    child: _busy
        ? const SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: Colors.white,
            ),
          )
        : Text(label),
  );

  Widget _methodButton({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) => OutlinedButton.icon(
    key: key,
    onPressed: _busy ? null : onPressed,
    style: OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(54),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    icon: Icon(icon),
    label: Text(label),
  );

  bool _phonePasswordEnabled(NativeAuthConfig config) =>
      config.methods.containsKey('phone_password')
      ? config.allows('phone_password')
      : config.allows('password');

  String? get _expectedGooglePhone =>
      _identity?.kind == 'phone' && _identity?.allows('password') == true
      ? _identity!.identifier
      : null;

  bool get _hasSubmit =>
      !_existingContactPhone &&
      (_pendingCommit != null ||
          ![
            _AuthStep.method,
            _AuthStep.recovery,
            _AuthStep.accounts,
          ].contains(_step));
  String get _submitKey => switch (_step) {
    _AuthStep.identifier => 'auth-continue',
    _AuthStep.password => 'auth-sign-in',
    _AuthStep.createPassword || _AuthStep.registration => 'auth-register',
    _AuthStep.otp => 'auth-verify-otp',
    _AuthStep.phone => 'auth-send-otp',
    _ => 'auth-continue',
  };
  String _submitLabel(AuthCopy copy) => _pendingCommit != null
      ? copy.continueLabel
      : switch (_step) {
          _AuthStep.identifier => copy.continueLabel,
          _AuthStep.password => copy.signIn,
          _AuthStep.createPassword ||
          _AuthStep.registration => copy.createAccount,
          _AuthStep.otp => copy.verifyCode,
          _AuthStep.phone =>
            _confirmContactPhone ? copy.confirmPhone : copy.sendOtp,
          _ => copy.continueLabel,
        };

  Future<void> _submit(AuthCopy copy, NativeAuthConfig config) async {
    if (_busy) return;
    if (_restartRequired) return;
    if (_pendingCommit case final result?) {
      await _perform((flow) => _acceptResult(result, flow));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _error = null);
      return;
    }
    await _perform((flow) async {
      switch (_step) {
        case _AuthStep.identifier:
          final identity = await _actions!.identify(
            _digits(_identifier.text.trim()),
          );
          if (!_active(flow)) return;
          _identity = identity;
          _identifier.text = identity.identifier;
          if (identity.allows('create_password')) {
            setState(() => _step = _AuthStep.createPassword);
          } else if (identity.allows('email_password') ||
              (identity.allows('password') && identity.allows('phone_otp'))) {
            setState(() => _step = _AuthStep.method);
          } else if (identity.allows('password')) {
            setState(() => _step = _AuthStep.password);
          } else if (identity.allows('phone_otp')) {
            await _sendOtp(flow, identity.identifier);
          } else {
            throw StateError('No native authentication method.');
          }
        case _AuthStep.password:
        case _AuthStep.createPassword:
          _registrationDetailsCollected = _step == _AuthStep.createPassword;
          final result = await _actions!.password(
            _identity!.identifier,
            _password.text,
          );
          if (_active(flow)) await _acceptResult(result, flow);
        case _AuthStep.phone:
          final phone = config.normalizeOtpPhone(_phone.text)!;
          if (_confirmContactPhone &&
              phone == _recoveryPhone &&
              _actions is NativePhoneEnrollmentActions) {
            try {
              final result = await (_actions as NativePhoneEnrollmentActions)
                  .confirmUnverifiedPhone(_continuation!.ticket, phone);
              if (_active(flow)) {
                _confirmContactPhone = false;
                await _acceptResult(result, flow);
              }
            } on AuthRepositoryException catch (error) {
              if (!_isExistingPhoneConflict(error)) rethrow;
              if (_active(flow)) _offerExistingPhone(phone);
            }
            return;
          }
          await _sendOtp(flow, phone, ticket: _continuation?.ticket);
        case _AuthStep.otp:
          final challenge = _challenge;
          final epoch = _otpEpoch;
          if (challenge == null) return;
          try {
            final result = await _actions!.verifyOtp(
              challenge,
              _digits(_otp.text.trim()),
              ticket: _otpTicket,
            );
            if (_active(flow) && epoch == _otpEpoch) {
              await _acceptResult(result, flow);
            }
          } catch (error) {
            if (_active(flow) && epoch == _otpEpoch) {
              _showOtpRecovery(error, challenge.phone, ticket: _otpTicket);
            }
          }
        case _AuthStep.registration:
          final continuation = _continuation!;
          try {
            final result = await _actions!.register(
              continuation.ticket,
              name: _name.text.trim(),
              password: _password.text,
              email: continuation.fields.contains('email')
                  ? _email.text.trim()
                  : null,
            );
            if (_active(flow)) await _acceptResult(result, flow);
          } on AuthRepositoryException catch (error) {
            if (!_isExistingPhoneConflict(error) || _recoveryPhone == null) {
              rethrow;
            }
            if (_active(flow)) _offerExistingPhone(_recoveryPhone!);
          }
        case _AuthStep.method:
        case _AuthStep.recovery:
        case _AuthStep.accounts:
          break;
      }
    });
  }

  Future<void> _perform(Future<void> Function(int flow) operation) async {
    if (_busy || _closing) return;
    final flow = _flow;
    final request = ++_operation;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.future);
      if (!_active(flow) || request != _operation) return;
      await operation(flow);
    } catch (error) {
      if (_active(flow) && request == _operation) {
        _showError(error);
      }
    } finally {
      if (_active(flow) && request == _operation) setState(() => _busy = false);
    }
  }

  Future<void> _sendOtp(
    int flow,
    String phone, {
    NativeOtpChallenge? previous,
    String? ticket,
  }) async {
    final epoch = ++_otpEpoch;
    _recoveryPhone = phone;
    NativeOtpChallenge challenge;
    var boundTicket = ticket;
    var preparedContact = false;
    DateTime? preparedExpiresAt;
    bool canConfirmContact() =>
        preparedContact &&
        boundTicket != null &&
        _continuation?.ticket == boundTicket &&
        preparedExpiresAt != null &&
        DateTime.now().isBefore(preparedExpiresAt);
    final enrollment = _actions;
    if (previous == null &&
        ref
                .read(nativeAuthConfigProvider)
                .value
                ?.supportsUnverifiedPhoneEnrollment ==
            true &&
        _identity?.allows('password') != true &&
        enrollment is NativePhoneEnrollmentActions) {
      try {
        final prepared = await (enrollment as NativePhoneEnrollmentActions)
            .preparePhone(phone, ticket: ticket);
        if (!_active(flow) || epoch != _otpEpoch) return;
        _continuation = prepared;
        boundTicket = prepared.ticket;
        preparedContact = true;
        preparedExpiresAt = DateTime.now().add(
          Duration(seconds: prepared.expiresIn),
        );
      } on AuthRepositoryException catch (error) {
        if (!_active(flow) || epoch != _otpEpoch) return;
        if (_isExistingPhoneConflict(error)) {
          _offerExistingPhone(phone);
          return;
        }
        if (error.code != 'mobishop_native_phone_proof_required') rethrow;
        // An existing incomplete account must retain its independent OTP proof.
      }
    }
    try {
      challenge = await _actions!.sendOtp(
        phone,
        resend: previous,
        ticket: boundTicket,
      );
    } catch (error) {
      if (_active(flow) && epoch == _otpEpoch) {
        _challenge = null;
        if (canConfirmContact()) {
          _showContactConfirmation(phone, boundTicket!);
        } else {
          _showOtpRecovery(error, phone, ticket: boundTicket, sendFailed: true);
        }
      }
      return;
    }
    // Always observe automaticResult so a late SDK failure is never unhandled.
    unawaited(
      challenge.automaticResult.then<void>(
        (result) {
          if (result != null && _active(flow) && epoch == _otpEpoch) {
            unawaited(_acceptResult(result, flow));
          }
        },
        onError: (Object error, StackTrace stack) {
          if (_active(flow) && epoch == _otpEpoch && !_resolving) {
            if (canConfirmContact() && _isOtpSendFailure(error)) {
              _showContactConfirmation(phone, boundTicket!);
            } else {
              _showOtpRecovery(
                error,
                phone,
                ticket: boundTicket,
                sendFailed: _isOtpSendFailure(error),
              );
            }
          }
        },
      ),
    );
    if (!_active(flow) || epoch != _otpEpoch) return;
    setState(() {
      _challenge = challenge;
      _otpTicket = boundTicket;
      _confirmContactPhone = false;
      _existingContactPhone = false;
      _otp.clear();
      _step = _AuthStep.otp;
    });
    _startResendTimer();
  }

  void _offerExistingPhone(String phone) {
    _otpEpoch++;
    _resendTimer?.cancel();
    setState(() {
      _existingContactPhone = true;
      _confirmContactPhone = false;
      _recoveryPhone = phone;
      _phone.text = phone;
      _challenge = null;
      _otpTicket = null;
      _otp.clear();
      _error = null;
      _step = _AuthStep.phone;
      _busy = false;
    });
  }

  bool _isExistingPhoneConflict(Object error) =>
      error is AuthRepositoryException &&
      const {
        'mobishop_native_existing_phone',
        'mobishop_native_phone_account_conflict',
      }.contains(error.code);

  bool _isOtpSendFailure(Object error) =>
      error is AuthRepositoryException &&
      const {
        'quota-exceeded',
        'too-many-requests',
        'app-not-authorized',
        'captcha-check-failed',
        'invalid-app-credential',
        'missing-client-identifier',
        'network-request-failed',
        'verification-timeout',
        'operation-not-allowed',
      }.contains(error.code);

  void _showContactConfirmation(String phone, String ticket) {
    _otpEpoch++;
    setState(() {
      _challenge = null;
      _confirmContactPhone = true;
      _existingContactPhone = false;
      _recoveryPhone = phone;
      _otpTicket = ticket;
      _phone.clear();
      _step = _AuthStep.phone;
      _busy = false;
      _error = null;
    });
  }

  void _showOtpRecovery(
    Object error,
    String phone, {
    String? ticket,
    bool sendFailed = false,
  }) {
    if (_isExistingPhoneConflict(error)) {
      _offerExistingPhone(phone);
      return;
    }
    final message = _messageFor(error);
    _operation++;
    _otpEpoch++; // A late automatic callback cannot sign in after recovery.
    setState(() {
      _recoveryPhone = phone;
      _otpTicket = ticket;
      _existingOtpSendFailed =
          sendFailed &&
          ticket == null &&
          _identity?.kind == 'phone' &&
          _identity?.allows('password') == true;
      _canRetryCode =
          _challenge != null &&
          error is AuthRepositoryException &&
          error.code == 'invalid-verification-code';
      _step = _AuthStep.recovery;
      _busy = false;
      _error = message;
      _restartRequired = _requiresRestart(error);
    });
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendSeconds = 60;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted ||
          ![_AuthStep.otp, _AuthStep.recovery].contains(_step) ||
          _closing) {
        timer.cancel();
        return;
      }
      setState(() => _resendSeconds--);
      if (_resendSeconds <= 0) timer.cancel();
    });
  }

  Future<void> _acceptResult(NativeAuthResult result, int flow) async {
    if (!_active(flow) || _resolving) return;
    _resolving = true;
    _operation++;
    _otpEpoch++;
    _resendTimer?.cancel();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registrationDetailsCollected &&
          result.status == NativeAuthStatus.registrationRequired &&
          !result.fields.contains('phone') &&
          !result.fields.contains('email')) {
        setState(() {
          _continuation = result;
          _step = _AuthStep.registration;
        });
        try {
          result = await _actions!.register(
            result.ticket,
            name: _name.text.trim(),
            password: _password.text,
          );
        } on AuthRepositoryException catch (error) {
          if (_isExistingPhoneConflict(error) && _recoveryPhone != null) {
            if (_active(flow)) _offerExistingPhone(_recoveryPhone!);
            return;
          }
          rethrow;
        }
        if (!_active(flow)) return;
      }
      switch (result.status) {
        case NativeAuthStatus.authenticated:
          _pendingCommit = result;
          await _actions!.commit(result);
          if (!_active(flow)) return;
          _pendingCommit = null;
          _completed = true;
          _finish();
        case NativeAuthStatus.selectAccount:
          setState(() {
            _continuation = result;
            _step = _AuthStep.accounts;
          });
        case NativeAuthStatus.registrationRequired:
          setState(() {
            _continuation = result;
            _step = result.fields.contains('phone')
                ? _AuthStep.phone
                : _AuthStep.registration;
          });
      }
    } catch (error) {
      if (_active(flow)) _showError(error);
    } finally {
      if (_active(flow)) {
        setState(() {
          _busy = false;
          _resolving = false;
        });
      }
    }
  }

  bool _requiresRestart(Object error) =>
      error is AuthRepositoryException &&
      const {
        'expired',
        'mobishop_native_invalid_ticket',
        'continuation_restart_required',
      }.contains(error.code);

  void _showError(Object error) {
    setState(() {
      _error = _messageFor(error);
      _restartRequired = _requiresRestart(error);
    });
  }

  String _messageFor(Object error) {
    final copy = AuthCopy.of(context);
    if (error is AuthRepositoryException) {
      if (['cancelled', 'canceled', 'sign_in_canceled'].contains(error.code)) {
        return copy.cancelled;
      }
      if (error.kind == AuthFailureKind.unauthorized &&
          (error.code == null || error.code == 'invalid-verification-code')) {
        if (_step == _AuthStep.otp) return copy.otpIncorrect;
        if (_step == _AuthStep.password || _step == _AuthStep.createPassword) {
          return copy.passwordIncorrect;
        }
      }
      if (error.kind == AuthFailureKind.rateLimited) return copy.rateLimited;
      final message = error.message.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      if (message.isNotEmpty) return message;
    }
    if (error is PlatformException &&
        [
          'canceled',
          'cancelled',
          'sign_in_canceled',
          'CANCELED',
        ].contains(error.code)) {
      return copy.cancelled;
    }
    return copy.genericError;
  }

  void _changeIdentifier() {
    _registrationDetailsCollected = false;
    _flow++;
    _operation++;
    _otpEpoch++;
    _cancelActions();
    _resendTimer?.cancel();
    setState(() {
      _step = _AuthStep.identifier;
      _restartRequired = false;
      _identity = null;
      _continuation = null;
      _challenge = null;
      _otpTicket = null;
      _recoveryPhone = null;
      _canRetryCode = false;
      _confirmContactPhone = false;
      _existingContactPhone = false;
      _existingOtpSendFailed = false;
      _resendSeconds = 0;
      _pendingCommit = null;
      _busy = false;
      _resolving = false;
      _error = null;
      for (final controller in [
        _password,
        _confirmation,
        _otp,
        _name,
        _email,
        _phone,
      ]) {
        controller.clear();
      }
    });
  }

  Future<void> _facebook() => _perform((flow) async {
    if (AppConfig.isCmsPreview || _actions is CmsPreviewAuthActions) {
      throw AuthRepositoryException(
        kind: AuthFailureKind.configuration,
        code: 'preview-only',
        message: Localizations.localeOf(context).languageCode == 'ar'
            ? 'دي معاينة لشاشة الدخول. جرّب تسجيل الدخول من تطبيق الموبايل.'
            : 'This is a sign-in preview. Try signing in from the mobile app.',
      );
    }
    await _actions!.cancel();
    if (!_active(flow)) return;
    final actions = _actions;
    if (ref.read(nativeAuthConfigProvider).value?.allows('facebook_native') ==
            true &&
        actions is NativeFacebookAuthActions) {
      try {
        final result = await (actions as NativeFacebookAuthActions).facebook();
        if (_active(flow)) {
          _identity = null;
          _registrationDetailsCollected = false;
          await _acceptResult(result, flow);
        }
        return;
      } on AuthRepositoryException catch (error) {
        // A previously installed binary may predate this store's SDK setup.
        // Only that local readiness failure may use the existing website flow.
        if (error.code != 'facebook-native-registration-required' ||
            ref.read(nativeAuthConfigProvider).value?.allows('facebook') !=
                true) {
          rethrow;
        }
        if (!_active(flow)) return;
      }
    }
    final attempt = WebsiteAuthAttempt();
    _websiteAttempt = attempt;
    try {
      await ref.read(authControllerProvider.future);
      if (!_active(flow)) return;
      await ref
          .read(authControllerProvider.notifier)
          .signInThroughWebsite(provider: 'facebook', attempt: attempt);
      if (_active(flow)) {
        _completed = true;
        _finish();
      }
    } finally {
      if (identical(_websiteAttempt, attempt)) _websiteAttempt = null;
    }
  });

  void _finish() {
    if (!widget.popOnSuccess) return;
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/account');
    }
  }

  void _close() {
    _closing = true;
    _flow++;
    _operation++;
    _otpEpoch++;
    _cancelActions();
    if (context.canPop()) {
      context.pop(false);
    } else {
      context.go('/account');
    }
  }

  static String _digits(String value) => value.split('').map((character) {
    final code = character.codeUnitAt(0);
    if (code >= 0x660 && code <= 0x669) return '${code - 0x660}';
    if (code >= 0x6f0 && code <= 0x6f9) return '${code - 0x6f0}';
    return character;
  }).join();
  static bool _validEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
  static bool _validPhone(String value) {
    final normalized = _digits(value.trim());
    final count = normalized.replaceAll(RegExp(r'\D'), '').length;
    return RegExp(r'^\+?[0-9\s()\-]+$').hasMatch(normalized) &&
        count >= 8 &&
        count <= 15;
  }

  static bool _validIdentifier(String value, NativeAuthConfig config) =>
      config.allows('email_password') && _validEmail(value) ||
      config.supportsPhone && _validPhone(value);
}

class _StoreMark extends StatelessWidget {
  const _StoreMark({
    required this.storeName,
    required this.logoUrl,
    this.aspectRatio = 0,
    this.scale = 1,
  });
  final String storeName;
  final String logoUrl;
  final double aspectRatio;
  final double scale;
  @override
  Widget build(BuildContext context) {
    final name = Center(
      child: Text(
        storeName,
        maxLines: 2,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: MobiShopColors.textPrimary,
        ),
      ),
    );
    return Semantics(
      header: true,
      child: SizedBox(
        height: 72,
        child: Center(
          child: logoUrl.trim().isEmpty
              ? name
              : AppNetworkImage(
                  key: const Key('auth-store-logo'),
                  imageUrl: logoUrl,
                  trimTransparentPadding: true,
                  contentAspectRatio: aspectRatio,
                  width: 220 * scale.clamp(0.5, 1.5),
                  height: 64 * scale.clamp(0.5, 1.5),
                  fit: BoxFit.contain,
                  semanticLabel: storeName,
                  placeholder: name,
                  errorWidget: name,
                ),
        ),
      ),
    );
  }
}

// The Material glyph has font padding and an open lower edge. Paint the round
// button explicitly so its visible diameter matches Google and Apple exactly.
class _FacebookMark extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      size.center(Offset.zero),
      size.shortestSide / 2,
      Paint()..color = const Color(0xFF1877F2),
    );
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    // Facebook 'f' contour from the existing Material facebook icon.
    canvas.drawPath(
      Path()
        ..moveTo(13, 21)
        ..lineTo(13, 15)
        ..lineTo(16, 15)
        ..lineTo(16, 12)
        ..lineTo(13, 12)
        ..lineTo(13, 10)
        ..cubicTo(13, 9.45, 13.45, 9, 14, 9)
        ..lineTo(16, 9)
        ..lineTo(16, 6)
        ..lineTo(13.5, 6)
        ..cubicTo(11.57, 6, 10, 7.57, 10, 9.5)
        ..lineTo(10, 12)
        ..lineTo(8, 12)
        ..lineTo(8, 15)
        ..lineTo(10, 15)
        ..lineTo(10, 21)
        ..close(),
      Paint()..color = Colors.white,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LoginHintPointer extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..close(),
      Paint()..color = const Color(0xFF4A4A4A),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
