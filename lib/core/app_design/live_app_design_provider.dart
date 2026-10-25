import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import 'app_design_bundle58.dart';
import 'live_app_design.dart';

const liveDesignEndpoint = String.fromEnvironment('APP_DESIGN_UPDATE_URL');
final liveAppDesignProvider =
    NotifierProvider<LiveDesignNotifier, AppDesignBundle58?>(
      LiveDesignNotifier.new,
    );

class LiveDesignNotifier extends Notifier<AppDesignBundle58?> {
  LiveAppDesign? _engine;
  @override
  AppDesignBundle58? build() {
    if (AppConfig.isCmsPreview ||
        liveDesignEndpoint.isEmpty ||
        AppConfig.appDesignBundle.isEmpty) {
      return null;
    }
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 8),
      ),
    );
    try {
      final connection = AppConfig.commerceConnection;
      final engine = LiveAppDesign(
        transport: DioLiveDesignTransport(dio, Uri.parse(liveDesignEndpoint)),
        cache: PreferencesLiveDesignCache(
          '$liveDesignEndpoint|${connection.platform.name}|${connection.storeOrigin}|${AppConfig.appDesignBundle}',
        ),
        platform: connection.platform,
        origin: connection.storeOrigin,
      );
      _engine = engine;
      engine.addListener(() {
        if (ref.mounted) state = engine.design;
      });
      ref.onDispose(() {
        engine.dispose();
        dio.close(force: true);
      });
    } catch (_) {
      dio.close(force: true);
    }
    return null;
  }

  void configure(bool active, bool safe) =>
      _engine?.configure(active: active, safeToApply: safe);
}

class LiveAppDesignHost extends ConsumerStatefulWidget {
  const LiveAppDesignHost({
    required this.child,
    required this.router,
    super.key,
  });
  final Widget child;
  final GoRouter router;
  @override
  ConsumerState<LiveAppDesignHost> createState() => _LiveAppDesignHostState();
}

class _LiveAppDesignHostState extends ConsumerState<LiveAppDesignHost>
    with WidgetsBindingObserver {
  bool _active = true;
  @override
  void initState() {
    super.initState();
    _active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    widget.router.routeInformationProvider.addListener(_schedule);
    _schedule();
  }

  void _schedule() => scheduleMicrotask(() {
    if (mounted) {
      ref
          .read(liveAppDesignProvider.notifier)
          .configure(
            _active,
            widget.router.routeInformationProvider.value.uri.path == '/',
          );
    }
  });
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _schedule();
  }

  @override
  void didUpdateWidget(covariant LiveAppDesignHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router.routeInformationProvider.removeListener(_schedule);
      widget.router.routeInformationProvider.addListener(_schedule);
      _schedule();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.router.routeInformationProvider.removeListener(_schedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
