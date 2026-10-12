import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/features/account/presentation/providers/customer_account_providers.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_state_providers.dart';
import 'package:mobishop_store_app/features/home/presentation/providers/home_providers.dart';
import 'package:mobishop_store_app/features/orders/presentation/providers/customer_orders_providers.dart';

import '../config/app_config.dart';
import '../commerce/commerce_connection.dart';
import '../push/push_notification_service.dart';
import 'store_change_bus.dart';
import 'store_change_signal.dart';
import 'store_change_transport.dart';
import 'store_live_updates.dart';

final nativeStoreChangeTransportProvider = Provider<DioStoreChangeTransport>((
  Ref ref,
) {
  AppConfig.requireWooCommerceCustomerTransport('live updates');
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  return DioStoreChangeTransport(dio: dio, storeUrl: AppConfig.apiBaseUrl);
});

final nativeStoreLiveUpdatesProvider = Provider<StoreLiveUpdates>((Ref ref) {
  AppConfig.requireWooCommerceCustomerTransport('live updates');
  final transport = ref.watch(nativeStoreChangeTransportProvider);
  String? currentToken() {
    final session = ref.read(authControllerProvider).value;
    return session != null && !session.isExpired ? session.token : null;
  }

  final updates = StoreLiveUpdates(
    transport: transport,
    configuredOrigin: transport.origin,
    currentSessionToken: currentToken,
  );
  final catalogBus = ref.read(storeCatalogChangeBusProvider);
  final changes = updates.changes.listen((domains) {
    if (!ref.mounted) return;
    if (domains.contains(StoreChangeDomain.catalog) ||
        domains.contains(StoreChangeDomain.stock)) {
      catalogBus.notifyCatalogChanged();
      // Home watches the normalized Material locale, not a raw ar_EG define.
      final home = homeLayoutProvider(_configuredHomeLocale());
      if (ref.exists(home)) ref.invalidate(home);
      // Only already loaded carts are refreshed. Reads use the normal customer
      // platform transport; mutations remain guarded by the existing controller.
      if (ref.exists(cartControllerProvider) &&
          ref.read(cartControllerProvider).hasValue) {
        unawaited(ref.read(cartControllerProvider.notifier).refreshCart());
      }
    }
    if (currentToken() == null || updates.sessionScope == null) return;
    if (domains.contains(StoreChangeDomain.orders) &&
        ref.exists(customerOrdersControllerProvider)) {
      unawaited(
        ref.read(customerOrdersControllerProvider).refreshLoadedPages(),
      );
    }
    if (domains.contains(StoreChangeDomain.profile) &&
        ref.exists(customerAccountProvider)) {
      // Form widgets reconcile only clean server fields; dirty user edits stay.
      ref.invalidate(customerAccountProvider);
    }
  });
  final push = PushNotificationService.instance.storeChangeHints.listen(
    updates.acceptHint,
  );
  ref.listen<(int?, String?)>(
    authControllerProvider.select(
      (AsyncValue<AuthSession?> state) =>
          (state.value?.user.id, state.value?.token),
    ),
    (previous, next) {
      // Cart ownership is handled by its own session-scoped provider graph.
      // Do not invalidate widget-facing ancestors inside this auth listener.
      if (previous != next) updates.sessionChanged();
    },
  );
  ref.onDispose(() {
    unawaited(changes.cancel());
    unawaited(push.cancel());
    updates.dispose();
  });
  return updates;
});

String _configuredHomeLocale() {
  final parts = AppConfig.storeLocale
      .trim()
      .split(RegExp('[-_]'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.isEmpty) return 'en';
  return Locale.fromSubtags(
    languageCode: parts.first.toLowerCase(),
    countryCode: parts.length > 1 ? parts[1].toUpperCase() : null,
  ).toLanguageTag();
}

/// One persistent host above every route, including Checkout and Profile.
class NativeLiveUpdatesHost extends ConsumerStatefulWidget {
  const NativeLiveUpdatesHost({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<NativeLiveUpdatesHost> createState() =>
      _NativeLiveUpdatesHostState();
}

class _NativeLiveUpdatesHostState extends ConsumerState<NativeLiveUpdatesHost>
    with WidgetsBindingObserver {
  StoreLiveUpdates? _updates;
  @override
  void initState() {
    super.initState();
    if (kIsWeb ||
        AppConfig.isCmsPreview ||
        !AppConfig.hasConfiguredStore ||
        !_hasSupportedLiveUpdateSource() ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    WidgetsBinding.instance.addObserver(this);
    _updates = ref.read(nativeStoreLiveUpdatesProvider);
    _updates!.setActive(
      WidgetsBinding.instance.lifecycleState == null ||
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _updates?.setActive(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updates?.setActive(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

bool _hasSupportedLiveUpdateSource() {
  try {
    return AppConfig.commercePlatform == CommercePlatform.wooCommerce;
  } on AppConfigurationException {
    // The startup gate displays invalid configuration. Do not create the Woo
    // auth/provider graph ahead of it, including for an invalid platform.
    return false;
  }
}
