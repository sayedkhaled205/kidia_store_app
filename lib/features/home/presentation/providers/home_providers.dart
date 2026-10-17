import 'package:mobishop_store_app/features/home/data/home_read_session.dart';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/app_design/app_design_providers58.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/features/catalog/presentation/providers/catalog_providers.dart';
import 'package:mobishop_store_app/features/home/data/datasources/home_remote_data_source.dart';
import 'package:mobishop_store_app/features/home/data/repositories/home_repository_impl.dart';
import 'package:mobishop_store_app/features/home/domain/entities/home_layout.dart';
import 'package:mobishop_store_app/features/home/domain/repositories/home_repository.dart';
import 'package:mobishop_store_app/features/home/data/models/home_layout_model.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_preview_layout_bridge.dart';

final cmsPreviewHomeLayoutJsonProvider = StreamProvider<Map<String, dynamic>?>(
  (Ref ref) =>
      CmsPreviewLayoutBridge.homeLayouts.where((layout) => layout != null),
);

final cmsPreviewHomeFocusTargetProvider = StreamProvider<String>(
  (Ref ref) => CmsPreviewLayoutBridge.homeFocusTargets,
);

final homeDioProvider = Provider<Dio>((Ref ref) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 25),
      responseType: ResponseType.json,
      headers: const <String, dynamic>{'Accept': 'application/json'},
    ),
  );

  ref.onDispose(dio.close);

  return dio;
});

final homeRemoteDataSourceProvider = Provider<HomeRemoteDataSource>((Ref ref) {
  if (!AppConfig.isCmsPreview &&
      AppConfig.commercePlatform != CommercePlatform.wooCommerce) {
    ref.watch(portableAppDesign58Provider);
    throw const AppConfigurationException(
      'Foreign Home design is hydrated directly from its catalog, not a WordPress Home reader.',
    );
  }
  if (AppConfig.useMockHomeLayout) {
    return const MockHomeRemoteDataSource();
  }

  return DioHomeRemoteDataSource(
    dio: ref.watch(homeDioProvider),
    endpoint: AppConfig.homeLayoutEndpoint,
  );
});

final homeRepositoryProvider = Provider<HomeRepository>((Ref ref) {
  return HomeRepositoryImpl(
    remoteDataSource: ref.watch(homeRemoteDataSourceProvider),
  );
});

final homeReadSessionProvider = Provider<HomeReadSession>((ref) {
  ref.watch(portableAppDesign58Provider);
  ref.watch(catalogRepositoryProvider);
  return HomeReadSession();
});

final homeLayoutProvider = FutureProvider.autoDispose.family<HomeLayout, String>(
  (Ref ref, String locale) async {
    final design = ref.watch(portableAppDesign58Provider);
    if (design != null) {
      final catalog = ref.watch(catalogRepositoryProvider);
      Timer? directRefresh;
      ref.onDispose(() => directRefresh?.cancel());
      try {
        return await ref
            .read(homeReadSessionProvider)
            .load(locale, () => design.hydrateHome(catalog, locale: locale));
      } finally {
        if (ref.mounted) {
          directRefresh = Timer(const Duration(seconds: 15), () {
            if (ref.mounted) ref.invalidateSelf();
          });
        }
      }
    }
    // Await the first real packet, rather than manufacturing a Future that
    // can never complete when the preview is first opened from another page.
    final previewState = ref.watch(cmsPreviewHomeLayoutJsonProvider);
    final Map<String, dynamic>? previewJson = AppConfig.isCmsPreview
        ? (previewState.value ??
              CmsPreviewLayoutBridge.currentHomeLayout ??
              await ref.watch(cmsPreviewHomeLayoutJsonProvider.future))
        : previewState.value;
    if (previewJson != null) {
      return HomeLayoutModel.fromJson(previewJson);
    }
    // The embedded CMS owns the canonical WordPress preview payload.
    // Falling through to the public store endpoint starts a second, much
    // slower Home request while WordPress normalizes the unsaved Builder state.
    if (AppConfig.isCmsPreview) {
      throw StateError('The builder has not supplied a Home layout.');
    }
    final HomeRepository repository = ref.watch(homeRepositoryProvider);
    Timer? refreshTimer;
    ref.onDispose(() => refreshTimer?.cancel());
    try {
      return await ref
          .read(homeReadSessionProvider)
          .load(locale, () => repository.getHomeLayout(locale: locale));
    } finally {
      // A slow initial read must be allowed to finish. Start the next refresh
      // interval only after this request settles, not while it is in flight.
      if (ref.mounted) {
        refreshTimer = Timer(const Duration(seconds: 15), () {
          if (ref.mounted) ref.invalidateSelf();
        });
      }
    }
  },
);
