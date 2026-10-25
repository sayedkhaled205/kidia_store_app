import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  final _otp = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  NativeAuthActions? _actions;
  NativeAuthIdentity? _identity;
  NativeAuthResult? _continuation;
  NativeAuthResult? _pendingCommit;
  NativeOtpChallenge? _challenge;
  String? _otpTicket;
  String? _recoveryPhone;
  bool _canRetryCode = false;
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
    final actions = _actions;
    if (actions != null) unawaited(actions.cancel().catchError((Object _) {}));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authControllerProvider);
    _actions = ref.watch(nativeAuthActionsProvider);
    final configState = ref.watch(nativeAuthConfigProvider);
    final config = configState.value;
    final hasIdentifier =
        config?.supportsPhone == true ||
        config?.allows('email_password') == true;
    final copy = AuthCopy.of(context);
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
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
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                        const SizedBox(height: 24),
                        Text(
                          _title(copy),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontSize: 23,
                                fontWeight: FontWeight.w700,
                                color: MobiShopColors.textPrimary,
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
                          ..._fields(copy, config),
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
                          if (_hasSubmit &&
                              (_step != _AuthStep.identifier ||
                                  hasIdentifier)) ...[
                            const SizedBox(height: 20),
                            _primaryButton(
                              key: Key(_submitKey),
                              label: _submitLabel(copy),
                              onPressed: () => _submit(copy, config),
                            ),
                          ],
                          if (_step == _AuthStep.password &&
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
                          if ([
                                _AuthStep.identifier,
                                _AuthStep.method,
                                _AuthStep.password,
                                _AuthStep.recovery,
                              ].contains(_step) &&
                              config.allows('google')) ...[
                            if (hasIdentifier) ...[
                              const SizedBox(height: 24),
                              Row(
                                key: const Key('auth-social-or'),
                                children: [
                                  const Expanded(child: Divider(endIndent: 16)),
                                  Text(copy.or, style: _secondaryStyle),
                                  const Expanded(child: Divider(indent: 16)),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            OutlinedButton.icon(
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
                                      final result = await _actions!.google();
                                      if (_active(flow)) {
                                        await _acceptResult(result, flow);
                                      }
                                    }),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                shape: const StadiumBorder(),
                              ),
                              icon: Image.asset(
                                'assets/branding/google-g.png',
                                key: const Key('auth-google-brand'),
                                width: 24,
                                height: 24,
                                fit: BoxFit.contain,
                                excludeFromSemantics: true,
                              ),
                              label: Text(copy.continueWithGoogle),
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
    _AuthStep.method => copy.chooseMethod,
    _AuthStep.recovery => copy.chooseAnotherMethod,
    _AuthStep.password => copy.existingTitle,
    _AuthStep.createPassword => copy.createTitle,
    _AuthStep.otp => copy.otpTitle,
    _AuthStep.accounts => copy.chooseAccount,
    _AuthStep.registration => copy.completeAccount,
    _AuthStep.phone => copy.verifyPhone,
  };

  List<Widget> _identitySummary(AuthCopy copy) {
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
          if (_identity!.allows('password'))
            _methodButton(
              key: const Key('auth-use-password'),
              label: copy.usePassword,
              icon: Icons.password_rounded,
              onPressed: () => setState(() {
                _step = _AuthStep.password;
                _error = null;
              }),
            ),
          if (_identity!.allows('phone_otp')) ...[
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
            copy.otpAlternatives,
            textAlign: TextAlign.center,
            style: _secondaryStyle,
          ),
          const SizedBox(height: 16),
          if (_identity?.allows('password') == true ||
              (_identity == null && config.allows('phone_password')))
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
                  _continuation = null;
                  _challenge = null;
                  _otpTicket = null;
                  _password.clear();
                  _step = _AuthStep.password;
                });
              }),
            ),
          const SizedBox(height: 12),
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
      case _AuthStep.password:
      case _AuthStep.createPassword:
        return _passwordFields(
          copy,
          creating: _step == _AuthStep.createPassword,
        );
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
        return [
          Text(
            copy.phoneRequiredForAccount,
            textAlign: TextAlign.center,
            style: _secondaryStyle,
          ),
          const SizedBox(height: 16),
          _textField(
            key: const Key('auth-phone'),
            controller: _phone,
            label: copy.internationalPhone,
            keyboard: TextInputType.phone,
            autofill: AutofillHints.telephoneNumber,
            validator: (value) =>
                RegExp(
                  r'^\+[1-9]\d{7,14}$',
                ).hasMatch(_digits(value?.trim() ?? ''))
                ? null
                : copy.internationalPhoneRequired,
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
      decoration: _decoration(label).copyWith(counterText: ''),
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
    labelText: label,
    filled: false,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFD9DFE3)),
    ),
  );

  Widget _primaryButton({
    required Key key,
    required String label,
    required VoidCallback onPressed,
  }) => FilledButton(
    key: key,
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
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

  bool get _hasSubmit =>
      _pendingCommit != null ||
      ![
        _AuthStep.method,
        _AuthStep.recovery,
        _AuthStep.accounts,
      ].contains(_step);
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
          _AuthStep.phone => copy.sendOtp,
          _ => copy.continueLabel,
        };

  Future<void> _submit(AuthCopy copy, NativeAuthConfig config) async {
    if (_busy) return;
    if (_pendingCommit case final result?) {
      await _perform((flow) => _acceptResult(result, flow));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
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
          } else if (identity.allows('password') &&
              identity.allows('phone_otp')) {
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
          final result = await _actions!.password(
            _identity!.identifier,
            _password.text,
          );
          if (_active(flow)) await _acceptResult(result, flow);
        case _AuthStep.phone:
          await _sendOtp(
            flow,
            _digits(_phone.text.trim()),
            ticket: _continuation!.ticket,
          );
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
          final result = await _actions!.register(
            continuation.ticket,
            name: _name.text.trim(),
            password: _password.text,
            email: continuation.fields.contains('email')
                ? _email.text.trim()
                : null,
          );
          if (_active(flow)) await _acceptResult(result, flow);
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
        setState(() => _error = _messageFor(error));
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
    NativeOtpChallenge challenge;
    try {
      challenge = await _actions!.sendOtp(
        phone,
        resend: previous,
        ticket: ticket,
      );
    } catch (error) {
      if (_active(flow) && epoch == _otpEpoch) {
        _challenge = null;
        _showOtpRecovery(error, phone, ticket: ticket);
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
            _showOtpRecovery(error, phone, ticket: ticket);
          }
        },
      ),
    );
    if (!_active(flow) || epoch != _otpEpoch) return;
    setState(() {
      _challenge = challenge;
      _otpTicket = ticket;
      _otp.clear();
      _step = _AuthStep.otp;
    });
    _startResendTimer();
  }

  void _showOtpRecovery(Object error, String phone, {String? ticket}) {
    final message = _messageFor(error);
    _operation++;
    _otpEpoch++; // A late automatic callback cannot sign in after recovery.
    setState(() {
      _recoveryPhone = phone;
      _otpTicket = ticket;
      _canRetryCode =
          _challenge != null &&
          error is AuthRepositoryException &&
          error.code == 'invalid-verification-code';
      _step = _AuthStep.recovery;
      _busy = false;
      _error = message;
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
      if (_active(flow)) setState(() => _error = _messageFor(error));
    } finally {
      if (_active(flow)) {
        setState(() {
          _busy = false;
          _resolving = false;
        });
      }
    }
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
    _flow++;
    _operation++;
    _otpEpoch++;
    _cancelActions();
    _resendTimer?.cancel();
    setState(() {
      _step = _AuthStep.identifier;
      _identity = null;
      _continuation = null;
      _challenge = null;
      _otpTicket = null;
      _recoveryPhone = null;
      _canRetryCode = false;
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
