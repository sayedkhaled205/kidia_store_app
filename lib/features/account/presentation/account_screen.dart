import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/core/theme/kidia_colors.dart';
import 'package:kidia_store_app/core/theme/kidia_radius.dart';
import 'package:kidia_store_app/core/theme/kidia_spacing.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:kidia_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kidia_store_app/features/cart/presentation/widgets/cart_icon_button.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  static const List<_AccountAction> _actions = <_AccountAction>[
    _AccountAction(
      id: 'orders',
      icon: Icons.receipt_long_outlined,
      arabicLabel: 'طلباتي',
      englishLabel: 'My orders',
    ),
    _AccountAction(
      id: 'addresses',
      icon: Icons.location_on_outlined,
      arabicLabel: 'العناوين المحفوظة',
      englishLabel: 'Saved addresses',
    ),
    _AccountAction(
      id: 'profile',
      icon: Icons.person_outline_rounded,
      arabicLabel: 'بيانات حسابي',
      englishLabel: 'My profile',
    ),
    _AccountAction(
      id: 'support',
      icon: Icons.support_agent_rounded,
      arabicLabel: 'خدمة العملاء',
      englishLabel: 'Customer service',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isArabic =
        Localizations.localeOf(context).languageCode.toLowerCase() == 'ar';
    final AsyncValue<AuthSession?> authState = ref.watch(
      authControllerProvider,
    );
    final AuthSession? session = authState.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: Text(isArabic ? 'حسابي' : 'Account'),
        actions: <Widget>[
          CartIconButton(onPressed: () => context.push('/cart')),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsetsDirectional.fromSTEB(
            KidiaSpacing.md,
            KidiaSpacing.md,
            KidiaSpacing.md,
            KidiaSpacing.xl,
          ),
          children: <Widget>[
            _AccountHeader(
              session: session,
              loading: authState.isLoading,
              isArabic: isArabic,
              onSignIn: () => context.push('/auth'),
            ),
            if (authState.hasError) ...<Widget>[
              const SizedBox(height: KidiaSpacing.sm),
              _SessionNotice(
                message: isArabic
                    ? 'تعذر قراءة جلسة الحساب. يمكنك تسجيل الدخول من جديد.'
                    : 'Could not restore the account session. You can sign in again.',
              ),
            ],
            const SizedBox(height: KidiaSpacing.lg),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  for (int index = 0; index < _actions.length; index++) ...<Widget>[
                    _AccountActionTile(
                      action: _actions[index],
                      isArabic: isArabic,
                      onTap: () => _openAction(
                        context,
                        session: session,
                        action: _actions[index],
                        isArabic: isArabic,
                      ),
                    ),
                    if (index < _actions.length - 1) const Divider(),
                  ],
                ],
              ),
            ),
            if (session != null) ...<Widget>[
              const SizedBox(height: KidiaSpacing.lg),
              OutlinedButton.icon(
                key: const Key('account-sign-out'),
                onPressed: () => _signOut(context, ref, isArabic),
                icon: const Icon(Icons.logout_rounded),
                label: Text(isArabic ? 'تسجيل الخروج' : 'Sign out'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openAction(
    BuildContext context, {
    required AuthSession? session,
    required _AccountAction action,
    required bool isArabic,
  }) async {
    if (session == null) {
      await context.push<bool>('/auth');
      return;
    }
    if (!context.mounted) {
      return;
    }
    final String label = action.label(isArabic);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'صفحة $label ستكون الخطوة التالية.'
                : '$label will be added in the next step.',
          ),
        ),
      );
  }

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
    bool isArabic,
  ) async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isArabic ? 'تم تسجيل الخروج.' : 'You have been signed out.',
          ),
        ),
      );
  }
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.session,
    required this.loading,
    required this.isArabic,
    required this.onSignIn,
  });

  final AuthSession? session;
  final bool loading;
  final bool isArabic;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final AuthSession? current = session;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KidiaSpacing.md),
        child: Row(
          children: <Widget>[
            Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(
                color: KidiaColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                current == null
                    ? Icons.person_outline_rounded
                    : Icons.person_rounded,
                size: 38,
                color: KidiaColors.primaryDark,
              ),
            ),
            const SizedBox(width: KidiaSpacing.md),
            Expanded(
              child: loading
                  ? const LinearProgressIndicator(
                      key: Key('account-session-loading'),
                      minHeight: 3,
                    )
                  : current == null
                  ? InkWell(
                      key: const Key('account-sign-in'),
                      borderRadius: BorderRadius.circular(KidiaRadius.md),
                      onTap: onSignIn,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    isArabic
                                        ? 'تسجيل الدخول / إنشاء حساب'
                                        : 'Sign in / Register',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isArabic
                                        ? 'تابع طلباتك وبياناتك على ${AppConfig.storeName}'
                                        : 'Manage your ${AppConfig.storeName} orders and details',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: KidiaColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          current.user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            current.user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: KidiaColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountActionTile extends StatelessWidget {
  const _AccountActionTile({
    required this.action,
    required this.isArabic,
    required this.onTap,
  });

  final _AccountAction action;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('account-action-${action.id}'),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: KidiaSpacing.md,
        vertical: KidiaSpacing.xs,
      ),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: KidiaColors.primaryLight,
          borderRadius: BorderRadius.circular(KidiaRadius.sm),
        ),
        child: Icon(action.icon, color: KidiaColors.primaryDark),
      ),
      title: Text(
        action.label(isArabic),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _SessionNotice extends StatelessWidget {
  const _SessionNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KidiaSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(KidiaRadius.md),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
      ),
    );
  }
}

class _AccountAction {
  const _AccountAction({
    required this.id,
    required this.icon,
    required this.arabicLabel,
    required this.englishLabel,
  });

  final String id;
  final IconData icon;
  final String arabicLabel;
  final String englishLabel;

  String label(bool isArabic) => isArabic ? arabicLabel : englishLabel;
}
