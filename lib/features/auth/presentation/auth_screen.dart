import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/core/theme/kidia_colors.dart';
import 'package:kidia_store_app/core/theme/kidia_radius.dart';
import 'package:kidia_store_app/core/theme/kidia_spacing.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_identity.dart';
import 'package:kidia_store_app/features/auth/domain/entities/social_auth.dart';
import 'package:kidia_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:kidia_store_app/features/auth/presentation/auth_copy.dart';
import 'package:kidia_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:url_launcher/url_launcher.dart';

enum _AuthStep { email, password, createPassword }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key, this.popOnSuccess = true});

  /// Checkout embeds this screen in-place and rebuilds when auth succeeds.
  /// Standalone account entry points pop back to their original destination.
  final bool popOnSuccess;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  _AuthStep _step = _AuthStep.email;
  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Start secure-session restoration before the customer submits a form.
    ref.watch(authControllerProvider);
    final AuthCopy copy = AuthCopy.of(context);
    return Scaffold(
      backgroundColor: KidiaColors.surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const Key('auth-close'),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: _busy ? null : _close,
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              KidiaSpacing.lg,
              KidiaSpacing.sm,
              KidiaSpacing.lg,
              KidiaSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _StoreMark(storeName: AppConfig.storeName),
                    const SizedBox(height: KidiaSpacing.xl),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _stepContent(copy),
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: KidiaSpacing.md),
                      _AuthError(message: _error!),
                    ],
                    const SizedBox(height: KidiaSpacing.lg),
                    FilledButton(
                      key: Key(_buttonKey),
                      onPressed: _busy ? null : () => _submit(copy),
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(_buttonLabel(copy)),
                    ),
                    if (_step != _AuthStep.email) ...<Widget>[
                      const SizedBox(height: KidiaSpacing.sm),
                      TextButton.icon(
                        key: const Key('auth-change-email'),
                        onPressed: _busy ? null : _changeEmail,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(copy.changeEmail),
                      ),
                    ],
                    if (_step == _AuthStep.password)
                      TextButton(
                        key: const Key('auth-forgot-password'),
                        onPressed: _busy ? null : _openPasswordReset,
                        child: Text(copy.forgotPassword),
                      ),
                    if (_step == _AuthStep.email) ...<Widget>[
                      const SizedBox(height: KidiaSpacing.xl),
                      _SocialAuthDivider(label: copy.or),
                      const SizedBox(height: KidiaSpacing.md),
                      _SocialAuthButtons(
                        copy: copy,
                        enabled: !_busy,
                        onProvider: (SocialAuthProvider provider) =>
                            _beginSocialSignIn(provider, copy),
                      ),
                    ],
                    const SizedBox(height: KidiaSpacing.xl),
                    _PrivacyNotice(
                      text: copy.privacyPrefix,
                      onTap: _openPrivacyPolicy,
                    ),
                    const SizedBox(height: KidiaSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 16,
                          color: KidiaColors.textSecondary,
                        ),
                        const SizedBox(width: KidiaSpacing.xs),
                        Flexible(
                          child: Text(
                            copy.secureNotice,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: KidiaColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepContent(AuthCopy copy) {
    return switch (_step) {
      _AuthStep.email => _EmailStep(
        key: const ValueKey<String>('email-step'),
        copy: copy,
        controller: _emailController,
      ),
      _AuthStep.password => _PasswordStep(
        key: const ValueKey<String>('password-step'),
        title: copy.existingTitle,
        subtitle: copy.existingSubtitle,
        email: _emailController.text.trim(),
        passwordLabel: copy.password,
        passwordError: copy.passwordRequired,
        controller: _passwordController,
        obscure: _obscurePassword,
        fieldKey: const Key('auth-password'),
        onToggleVisibility: () {
          setState(() => _obscurePassword = !_obscurePassword);
        },
      ),
      _AuthStep.createPassword => _CreatePasswordStep(
        key: const ValueKey<String>('create-password-step'),
        copy: copy,
        email: _emailController.text.trim(),
        passwordController: _passwordController,
        confirmationController: _confirmPasswordController,
        obscurePassword: _obscurePassword,
        obscureConfirmation: _obscureConfirmation,
        onTogglePassword: () {
          setState(() => _obscurePassword = !_obscurePassword);
        },
        onToggleConfirmation: () {
          setState(() => _obscureConfirmation = !_obscureConfirmation);
        },
      ),
    };
  }

  String get _buttonKey => switch (_step) {
    _AuthStep.email => 'auth-continue',
    _AuthStep.password => 'auth-sign-in',
    _AuthStep.createPassword => 'auth-register',
  };

  String _buttonLabel(AuthCopy copy) => switch (_step) {
    _AuthStep.email => copy.continueLabel,
    _AuthStep.password => copy.signIn,
    _AuthStep.createPassword => copy.createAccount,
  };

  Future<void> _submit(AuthCopy copy) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      switch (_step) {
        case _AuthStep.email:
          final AuthIdentity identity = await ref
              .read(authControllerProvider.notifier)
              .identify(_emailController.text);
          if (!mounted) {
            return;
          }
          _emailController.text = identity.email;
          setState(() {
            _step = identity.isRegistered
                ? _AuthStep.password
                : _AuthStep.createPassword;
          });
          break;
        case _AuthStep.password:
          await ref
              .read(authControllerProvider.notifier)
              .signIn(
                email: _emailController.text,
                password: _passwordController.text,
              );
          if (mounted) {
            _finish();
          }
          break;
        case _AuthStep.createPassword:
          await ref
              .read(authControllerProvider.notifier)
              .register(
                email: _emailController.text,
                password: _passwordController.text,
              );
          if (mounted) {
            _finish();
          }
          break;
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = _messageFor(error, copy));
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _beginSocialSignIn(
    SocialAuthProvider provider,
    AuthCopy copy,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final Uri authorizeUri = await ref
          .read(authControllerProvider.notifier)
          .beginSocialSignIn(
            provider: provider,
            returnPath: widget.popOnSuccess ? '/account' : '/checkout',
          );
      final bool launched = await launchUrl(
        authorizeUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('The social sign-in browser could not be opened.');
      }
    } catch (error) {
      if (mounted) {
        final String message = error is AuthRepositoryException
            ? _messageFor(error, copy)
            : copy.socialSignInError;
        setState(() => _error = message);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _messageFor(Object error, AuthCopy copy) {
    if (error is AuthRepositoryException) {
      if (error.kind == AuthFailureKind.unauthorized) {
        return copy.passwordIncorrect;
      }
      if (error.kind == AuthFailureKind.rateLimited) {
        return copy.rateLimited;
      }
      final String message = error.message
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .trim();
      if (message.isNotEmpty) {
        return message;
      }
    }
    return copy.genericError;
  }

  void _changeEmail() {
    setState(() {
      _step = _AuthStep.email;
      _passwordController.clear();
      _confirmPasswordController.clear();
      _error = null;
    });
  }

  void _finish() {
    if (!widget.popOnSuccess) {
      return;
    }
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/account');
    }
  }

  void _close() {
    if (context.canPop()) {
      context.pop(false);
    } else {
      context.go('/account');
    }
  }

  Future<void> _openPasswordReset() {
    return _openStorePath('/my-account/lost-password/');
  }

  Future<void> _openPrivacyPolicy() {
    return _openStorePath('/privacy-policy/');
  }

  Future<void> _openStorePath(String path) async {
    final Uri base = Uri.parse(AppConfig.apiBaseUrl.trim());
    final String installPath = base.path == '/'
        ? ''
        : base.path.replaceFirst(RegExp(r'/$'), '');
    final Uri uri = base.replace(
      path: '$installPath$path',
      query: null,
      fragment: null,
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _StoreMark extends StatelessWidget {
  const _StoreMark({required this.storeName});

  final String storeName;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: KidiaColors.primaryLight,
              borderRadius: BorderRadius.circular(KidiaRadius.full),
            ),
            child: const Icon(
              Icons.shopping_bag_rounded,
              color: KidiaColors.primaryDark,
              size: 30,
            ),
          ),
          const SizedBox(width: KidiaSpacing.sm),
          Flexible(
            child: Text(
              storeName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: KidiaColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailStep extends StatelessWidget {
  const _EmailStep({
    required this.copy,
    required this.controller,
    super.key,
  });

  final AuthCopy copy;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          copy.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: KidiaSpacing.xs),
        Text(
          copy.intro,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: KidiaColors.textSecondary,
          ),
        ),
        const SizedBox(height: KidiaSpacing.xl),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextFormField(
            key: const Key('auth-email'),
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.email],
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: copy.email,
              hintText: copy.emailHint,
              prefixIcon: const Icon(Icons.email_outlined),
            ),
            validator: (String? value) {
              final String email = value?.trim() ?? '';
              return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)
                  ? null
                  : copy.emailRequired;
            },
          ),
        ),
      ],
    );
  }
}

class _PasswordStep extends StatelessWidget {
  const _PasswordStep({
    required this.title,
    required this.subtitle,
    required this.email,
    required this.passwordLabel,
    required this.passwordError,
    required this.controller,
    required this.obscure,
    required this.fieldKey,
    required this.onToggleVisibility,
    super.key,
  });

  final String title;
  final String subtitle;
  final String email;
  final String passwordLabel;
  final String passwordError;
  final TextEditingController controller;
  final bool obscure;
  final Key fieldKey;
  final VoidCallback onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: KidiaSpacing.xs),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: KidiaColors.textSecondary,
          ),
        ),
        const SizedBox(height: KidiaSpacing.md),
        _SelectedEmail(email: email),
        const SizedBox(height: KidiaSpacing.lg),
        Directionality(
          textDirection: TextDirection.ltr,
          child: TextFormField(
            key: fieldKey,
            controller: controller,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const <String>[AutofillHints.password],
            decoration: InputDecoration(
              labelText: passwordLabel,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                onPressed: onToggleVisibility,
                icon: Icon(
                  obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (String? value) => value?.isNotEmpty == true
                ? null
                : passwordError,
          ),
        ),
      ],
    );
  }
}

class _CreatePasswordStep extends StatelessWidget {
  const _CreatePasswordStep({
    required this.copy,
    required this.email,
    required this.passwordController,
    required this.confirmationController,
    required this.obscurePassword,
    required this.obscureConfirmation,
    required this.onTogglePassword,
    required this.onToggleConfirmation,
    super.key,
  });

  final AuthCopy copy;
  final String email;
  final TextEditingController passwordController;
  final TextEditingController confirmationController;
  final bool obscurePassword;
  final bool obscureConfirmation;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          copy.createTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: KidiaSpacing.xs),
        Text(
          copy.createSubtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: KidiaColors.textSecondary,
          ),
        ),
        const SizedBox(height: KidiaSpacing.md),
        _SelectedEmail(email: email),
        const SizedBox(height: KidiaSpacing.lg),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: <Widget>[
              TextFormField(
                key: const Key('auth-create-password'),
                controller: passwordController,
                obscureText: obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: copy.password,
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: onTogglePassword,
                    icon: Icon(
                      obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (String? value) {
                  if ((value ?? '').length < 8) {
                    return copy.passwordTooShort;
                  }
                  return null;
                },
              ),
              const SizedBox(height: KidiaSpacing.md),
              TextFormField(
                key: const Key('auth-confirm-password'),
                controller: confirmationController,
                obscureText: obscureConfirmation,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: copy.confirmPassword,
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                  suffixIcon: IconButton(
                    onPressed: onToggleConfirmation,
                    icon: Icon(
                      obscureConfirmation
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (String? value) => value == passwordController.text
                    ? null
                    : copy.passwordMismatch,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SelectedEmail extends StatelessWidget {
  const _SelectedEmail({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KidiaSpacing.md,
        vertical: KidiaSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: KidiaColors.primaryLight,
        borderRadius: BorderRadius.circular(KidiaRadius.md),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(
              Icons.alternate_email_rounded,
              size: 18,
              color: KidiaColors.primaryDark,
            ),
            const SizedBox(width: KidiaSpacing.xs),
            Flexible(
              child: Text(
                email,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: KidiaColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialAuthDivider extends StatelessWidget {
  const _SocialAuthDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('auth-social-or'),
      children: <Widget>[
        const Expanded(child: Divider(indent: 72, endIndent: 16)),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: KidiaColors.textSecondary,
          ),
        ),
        const Expanded(child: Divider(indent: 16, endIndent: 72)),
      ],
    );
  }
}

class _SocialAuthButtons extends StatelessWidget {
  const _SocialAuthButtons({
    required this.copy,
    required this.enabled,
    required this.onProvider,
  });

  final AuthCopy copy;
  final bool enabled;
  final ValueChanged<SocialAuthProvider> onProvider;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _SocialCircleButton(
            key: const Key('auth-google'),
            label: copy.continueWithGoogle,
            enabled: enabled,
            onTap: () => onProvider(SocialAuthProvider.google),
            backgroundColor: Colors.white,
            borderColor: const Color(0xFFE4E7EC),
            child: const _GoogleMark(),
          ),
          const SizedBox(width: KidiaSpacing.lg),
          _SocialCircleButton(
            key: const Key('auth-facebook'),
            label: copy.continueWithFacebook,
            enabled: enabled,
            onTap: () => onProvider(SocialAuthProvider.facebook),
            backgroundColor: const Color(0xFF1877F2),
            borderColor: const Color(0xFF1877F2),
            child: const Text(
              'f',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                height: 1.12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 30,
      child: CustomPaint(painter: _GoogleMarkPainter()),
    );
  }
}

class _GoogleMarkPainter extends CustomPainter {
  const _GoogleMarkPainter();

  static const double _strokeWidth = 4.8;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect ring = Offset(_strokeWidth / 2, _strokeWidth / 2) &
        Size(
          size.width - _strokeWidth,
          size.height - _strokeWidth,
        );
    void arc(Color color, double start, double sweep) {
      canvas.drawArc(
        ring,
        start,
        sweep,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.butt,
      );
    }

    arc(const Color(0xFFEA4335), -2.36, 2.22);
    arc(const Color(0xFF4285F4), -0.14, 1.72);
    arc(const Color(0xFF34A853), 1.58, 1.28);
    arc(const Color(0xFFFBBC05), 2.86, 1.07);
    canvas.drawLine(
      Offset(size.width * 0.52, size.height * 0.5),
      Offset(size.width - 1.2, size.height * 0.5),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleMarkPainter oldDelegate) => false;
}

class _SocialCircleButton extends StatelessWidget {
  const _SocialCircleButton({
    required this.label,
    required this.enabled,
    required this.onTap,
    required this.backgroundColor,
    required this.borderColor,
    required this.child,
    super.key,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color borderColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: Material(
          color: backgroundColor,
          shape: CircleBorder(side: BorderSide(color: borderColor)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onTap : null,
            customBorder: const CircleBorder(),
            child: SizedBox.square(
              dimension: 62,
              child: Center(
                child: AnimatedOpacity(
                  opacity: enabled ? 1 : 0.45,
                  duration: const Duration(milliseconds: 120),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthError extends StatelessWidget {
  const _AuthError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('auth-error'),
      padding: const EdgeInsets.all(KidiaSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(KidiaRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: KidiaSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const Key('auth-privacy'),
      onPressed: onTap,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: KidiaColors.textSecondary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
