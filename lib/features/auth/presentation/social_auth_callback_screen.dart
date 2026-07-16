import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/core/theme/kidia_colors.dart';
import 'package:kidia_store_app/core/theme/kidia_spacing.dart';
import 'package:kidia_store_app/features/auth/domain/entities/social_auth.dart';
import 'package:kidia_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:kidia_store_app/features/auth/presentation/auth_copy.dart';
import 'package:kidia_store_app/features/auth/presentation/providers/auth_providers.dart';

class SocialAuthCallbackScreen extends ConsumerStatefulWidget {
  const SocialAuthCallbackScreen({
    required this.code,
    required this.state,
    super.key,
  });

  final String code;
  final String state;

  @override
  ConsumerState<SocialAuthCallbackScreen> createState() =>
      _SocialAuthCallbackScreenState();
}

class _SocialAuthCallbackScreenState
    extends ConsumerState<SocialAuthCallbackScreen> {
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _complete());
  }

  @override
  Widget build(BuildContext context) {
    final AuthCopy copy = AuthCopy.of(context);
    final bool isArabic = copy.isArabic;
    return Scaffold(
      backgroundColor: KidiaColors.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(KidiaSpacing.xl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  if (_busy)
                    const CircularProgressIndicator(
                      key: Key('social-auth-callback-loading'),
                    )
                  else
                    Icon(
                      Icons.error_outline_rounded,
                      size: 52,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  const SizedBox(height: KidiaSpacing.lg),
                  Text(
                    _busy
                        ? (isArabic
                              ? 'جارٍ إكمال تسجيل الدخول…'
                              : 'Completing sign-in…')
                        : (isArabic
                              ? 'تعذر إكمال تسجيل الدخول'
                              : 'Could not complete sign-in'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: KidiaSpacing.sm),
                    Text(
                      _error!,
                      key: const Key('social-auth-callback-error'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: KidiaColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: KidiaSpacing.lg),
                    FilledButton(
                      key: const Key('social-auth-callback-retry'),
                      onPressed: _complete,
                      child: Text(isArabic ? 'إعادة المحاولة' : 'Try again'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/auth'),
                      child: Text(
                        isArabic ? 'العودة لتسجيل الدخول' : 'Back to sign in',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _complete() async {
    if (widget.code.trim().isEmpty || widget.state.trim().isEmpty) {
      setState(() {
        _busy = false;
        _error = AuthCopy.of(context).socialSignInError;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // A deep link can cold-start the app. Let secure-session restoration
      // finish before replacing the controller state with the social session.
      await ref.read(authControllerProvider.future);
      if (!mounted) {
        return;
      }
      final SocialAuthCompletion completion = await ref
          .read(authControllerProvider.notifier)
          .completeSocialSignIn(
            code: widget.code,
            callbackState: widget.state,
          );
      if (mounted) {
        context.go(completion.returnPath);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final AuthCopy copy = AuthCopy.of(context);
      final String message = error is AuthRepositoryException
          ? error.message.replaceAll(RegExp(r'<[^>]*>'), '').trim()
          : copy.socialSignInError;
      setState(() {
        _busy = false;
        _error = message.isEmpty ? copy.socialSignInError : message;
      });
    }
  }
}
