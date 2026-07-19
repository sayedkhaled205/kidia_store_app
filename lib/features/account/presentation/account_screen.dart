import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/core/theme/kidia_colors.dart';
import 'package:kidia_store_app/core/theme/kidia_radius.dart';
import 'package:kidia_store_app/core/theme/kidia_spacing.dart';
import 'package:kidia_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:kidia_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:kidia_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';

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
    final CmsPageLayout pageLayout =
        ref.watch(cmsPageLayoutProvider('account')).value ??
        CmsPageLayout.fallback('account');
    final CmsPageComponent summarySettings = pageLayout.element(
      'account_summary',
    );
    final CmsPageComponent menuSettings = pageLayout.element('account_menu');
    final List<_AccountAction> visibleActions = _visibleActions(menuSettings);

    return CmsPageScaffold(
      layout: pageLayout,
      defaultTitle: isArabic ? 'حسابي' : 'Account',
      actions: <CmsPageHeaderAction>[
          CmsPageHeaderAction(
            type: 'cart',
            icon: Icons.shopping_bag_outlined,
            tooltip: 'Cart',
            onPressed: () => context.push('/cart'),
          ),
      ],
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
            if (summarySettings.enabled)
              CmsElementFrame(component: summarySettings, child: _AccountHeader(
              session: session,
              loading: authState.isLoading,
              isArabic: isArabic,
              onSignIn: () => context.push('/auth'),
              avatarSize: summarySettings.number('avatar_size', 66),
              guestTitle: summarySettings.string(
                'guest_title',
                isArabic ? 'تسجيل الدخول / إنشاء حساب' : 'Sign in / Register',
              ),
            )),
            if (authState.hasError) ...<Widget>[
              const SizedBox(height: KidiaSpacing.sm),
              _SessionNotice(
                message: isArabic
                    ? 'تعذر قراءة جلسة الحساب. يمكنك تسجيل الدخول من جديد.'
                    : 'Could not restore the account session. You can sign in again.',
              ),
            ],
            if (menuSettings.enabled) const SizedBox(height: KidiaSpacing.lg),
            if (menuSettings.enabled)
              CmsElementFrame(component: menuSettings, child: Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  for (int index = 0; index < visibleActions.length; index++) ...<Widget>[
                    _AccountActionTile(
                      action: visibleActions[index],
                      isArabic: isArabic,
                      onTap: () => _openAction(
                        context,
                        session: session,
                        action: visibleActions[index],
                      ),
                    ),
                    if (index < visibleActions.length - 1) const Divider(),
                  ],
                ],
              ),
            )),
            if (session != null && pageLayout.element('logout_button').enabled) ...<Widget>[
              const SizedBox(height: KidiaSpacing.lg),
              CmsElementFrame(component: pageLayout.element('logout_button'), child: OutlinedButton.icon(
                key: const Key('account-sign-out'),
                onPressed: () => _signOut(context, ref, isArabic),
                icon: const Icon(Icons.logout_rounded),
                label: Text(isArabic ? 'تسجيل الخروج' : 'Sign out'),
              )),
            ],
          ],
        ),
      ),
    );
  }

  List<_AccountAction> _visibleActions(CmsPageComponent settings) {
    return _actions.where((_AccountAction action) {
      return settings.boolean('show_${action.id}', true);
    }).toList(growable: false);
  }

  Future<void> _openAction(
    BuildContext context, {
    required AuthSession? session,
    required _AccountAction action,
  }) async {
    if (session == null) {
      await context.push<bool>('/auth');
      return;
    }
    if (!context.mounted) {
      return;
    }
    final String? route = switch (action.id) {
      'orders' => '/orders',
      'addresses' => '/addresses',
      'profile' => '/profile',
      'support' => '/support',
      _ => null,
    };
    if (route != null) {
      await context.push<void>(route);
    }
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
    required this.avatarSize,
    required this.guestTitle,
  });

  final AuthSession? session;
  final bool loading;
  final bool isArabic;
  final VoidCallback onSignIn;
  final double avatarSize;
  final String guestTitle;

  @override
  Widget build(BuildContext context) {
    final AuthSession? current = session;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KidiaSpacing.md),
        child: Row(
          children: <Widget>[
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: const BoxDecoration(
                color: KidiaColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                current == null
                    ? Icons.person_outline_rounded
                    : Icons.person_rounded,
                size: avatarSize * 0.58,
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
                                    guestTitle,
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
