import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/theme/mobishop_colors.dart';
import 'package:mobishop_store_app/core/theme/mobishop_radius.dart';
import 'package:mobishop_store_app/core/theme/mobishop_spacing.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/preview_identity_provider.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/widgets/cms_page_chrome.dart';

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
    final previewIdentity = AppConfig.isCmsPreview
        ? ref.watch(previewIdentityProvider).asData?.value
        : null;
    final storeName = previewIdentity?['app_name'] as String? ?? AppConfig.storeName;
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
    final bool flat = menuSettings.boolean('compact_family', false);

    return CmsPageScaffold(
      layout: pageLayout,
      defaultTitle: isArabic ? 'حسابي' : 'Account',
      actions: <CmsPageHeaderAction>[
        CmsPageHeaderAction(
          type: 'cart',
          icon: Icons.shopping_bag_outlined,
          tooltip: isArabic ? 'السلة' : 'Cart',
          onPressed: () => context.push('/cart'),
        ),
      ],
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsetsDirectional.fromSTEB(
            cmsContentHorizontalPadding(pageLayout),
            MobiShopSpacing.md,
            cmsContentHorizontalPadding(pageLayout),
            MobiShopSpacing.xl,
          ),
          children: <Widget>[
            if (summarySettings.enabled)
              CmsElementFrame(
                component: summarySettings,
                child: _AccountHeader(
                  storeName: storeName,
                  session: session,
                  loading: authState.isLoading,
                  isArabic: isArabic,
                  onSignIn: () => context.push('/auth'),
                  avatarSize: summarySettings.number('avatar_size', 66),
                  guestTitle: summarySettings.string(
                    'guest_title',
                    isArabic
                        ? 'تسجيل الدخول / إنشاء حساب'
                        : 'Sign in / Register',
                  ),
                  showEmail: summarySettings.boolean('show_email', true),
                  cardStyle: summarySettings.string('card_style', 'elevated'),
                ),
              ),
            if (authState.hasError) ...<Widget>[
              const SizedBox(height: MobiShopSpacing.sm),
              _SessionNotice(
                message: isArabic
                    ? 'تعذر قراءة جلسة الحساب. يمكنك تسجيل الدخول من جديد.'
                    : 'Could not restore the account session. You can sign in again.',
              ),
            ],
            if (menuSettings.enabled)
              const SizedBox(height: MobiShopSpacing.lg),
            if (menuSettings.enabled)
              CmsElementFrame(
                component: menuSettings,
                child: Card(
                  elevation: flat ? 0 : null,
                  margin: flat ? const EdgeInsets.symmetric(horizontal: 16) : null,
                  shape: flat ? const RoundedRectangleBorder() : null,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: <Widget>[
                      for (
                        int index = 0;
                        index < visibleActions.length;
                        index++
                      ) ...<Widget>[
                        _AccountActionTile(
                          action: visibleActions[index],
                          flat: flat,
                          isArabic: isArabic,
                          onTap: () => _openAction(
                            context,
                            session: session,
                            action: visibleActions[index],
                          ),
                        ),
                        if (!flat && index < visibleActions.length - 1) const Divider(),
                      ],
                    ],
                  ),
                ),
              ),
            if (session != null &&
                pageLayout.element('logout_button').enabled) ...<Widget>[
              const SizedBox(height: MobiShopSpacing.lg),
              CmsElementFrame(
                component: pageLayout.element('logout_button'),
                child: OutlinedButton.icon(
                  key: const Key('account-sign-out'),
                  onPressed: () => _signOut(context, ref, isArabic),
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(isArabic ? 'تسجيل الخروج' : 'Sign out'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_AccountAction> _visibleActions(CmsPageComponent settings) {
    return _actions
        .where((_AccountAction action) {
          return settings.boolean('show_${action.id}', true);
        })
        .toList(growable: false);
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
    required this.storeName,
    required this.session,
    required this.loading,
    required this.isArabic,
    required this.onSignIn,
    required this.avatarSize,
    required this.guestTitle,
    required this.showEmail,
    required this.cardStyle,
  });

  final AuthSession? session;
  final String storeName;
  final bool loading;
  final bool isArabic;
  final VoidCallback onSignIn;
  final double avatarSize;
  final String guestTitle;
  final bool showEmail;
  final String cardStyle;

  @override
  Widget build(BuildContext context) {
    final AuthSession? current = session;
    final bool outlined = cardStyle == 'outlined';
    final bool elevated = cardStyle == 'elevated';
    return Card(
      elevation: elevated ? null : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MobiShopRadius.md),
        side: outlined
            ? BorderSide(color: Theme.of(context).colorScheme.outlineVariant)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(MobiShopSpacing.md),
        child: Row(
          children: <Widget>[
            Container(
              width: avatarSize,
              height: avatarSize,
              decoration: const BoxDecoration(
                color: MobiShopColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                current == null
                    ? Icons.person_outline_rounded
                    : Icons.person_rounded,
                size: avatarSize * 0.58,
                color: MobiShopColors.primaryDark,
              ),
            ),
            const SizedBox(width: MobiShopSpacing.md),
            Expanded(
              child: loading
                  ? const LinearProgressIndicator(
                      key: Key('account-session-loading'),
                      minHeight: 3,
                    )
                  : current == null
                  ? InkWell(
                      key: const Key('account-sign-in'),
                      borderRadius: BorderRadius.circular(MobiShopRadius.md),
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
                                        ? 'تابع طلباتك وبياناتك على $storeName'
                                        : 'Manage your $storeName orders and details',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: MobiShopColors.textSecondary,
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
                        if (showEmail) ...<Widget>[
                          const SizedBox(height: 4),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              current.user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: MobiShopColors.textSecondary,
                                  ),
                            ),
                          ),
                        ],
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
    this.flat = false,
    required this.isArabic,
    required this.onTap,
  });

  final _AccountAction action;
  final bool flat;
  final bool isArabic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('account-action-${action.id}'),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MobiShopSpacing.md,
        vertical: MobiShopSpacing.xs,
      ),
      minTileHeight: flat ? 64 : null,
      leading: flat ? Icon(action.icon, size: 24, color: MobiShopColors.textPrimary) : Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: MobiShopColors.primaryLight,
          borderRadius: BorderRadius.circular(MobiShopRadius.sm),
        ),
        child: Icon(action.icon, color: MobiShopColors.primaryDark),
      ),
      title: Text(
        action.label(isArabic),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: flat ? FontWeight.w400 : FontWeight.w800, fontSize: flat ? 16 : null),
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
      padding: const EdgeInsets.all(MobiShopSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(MobiShopRadius.md),
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
