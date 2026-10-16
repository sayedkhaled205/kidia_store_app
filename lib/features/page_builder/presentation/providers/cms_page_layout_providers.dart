import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/core/config/app_config.dart';
import 'package:mobishop_store_app/core/app_design/app_design_providers58.dart';
import 'package:mobishop_store_app/core/commerce/commerce_connection.dart';
import 'package:mobishop_store_app/features/home/presentation/providers/home_providers.dart';
import 'package:mobishop_store_app/features/page_builder/data/cms_page_layout_remote_data_source.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_preview_layout_bridge.dart';

final cmsPreviewLayoutJsonProvider =
    StreamProvider.family<Map<String, dynamic>?, String>(
      (Ref ref, String page) => CmsPreviewLayoutBridge.layoutsFor(page),
    );

final Provider<CmsPageLayoutRemoteDataSource>
cmsPageLayoutRemoteDataSourceProvider = Provider<CmsPageLayoutRemoteDataSource>(
  (Ref ref) {
    if (!AppConfig.isCmsPreview &&
        AppConfig.commercePlatform != CommercePlatform.wooCommerce) {
      ref.watch(portableAppDesign58Provider);
      throw const AppConfigurationException(
        'Foreign page chrome uses saved app design, not WordPress.',
      );
    }
    return CmsPageLayoutRemoteDataSource(ref.watch(homeDioProvider));
  },
);

final cmsPageLayoutProvider = FutureProvider.family<CmsPageLayout, String>((
  Ref ref,
  String page,
) async {
  final design = ref.watch(portableAppDesign58Provider);
  if (design != null) {
    return design.pageLayout(page);
  }
  final Map<String, dynamic>? previewJson = ref
      .watch(cmsPreviewLayoutJsonProvider(page))
      .value;
  if (previewJson != null) {
    return CmsPageLayout.fromJson(previewJson);
  }
  // Render the correctly sized local chrome immediately while WordPress
  // normalizes the live form. The bridge emission rebuilds this provider with
  // the exact unsaved settings as soon as they arrive.
  if (AppConfig.isCmsPreview) {
    return CmsPageLayout.fallback(page);
  }
  Timer? refreshTimer;
  ref.onDispose(() => refreshTimer?.cancel());
  try {
    if (AppConfig.useMockHomeLayout) {
      return CmsPageLayout.fallback(page);
    }
    final Map<String, dynamic> json = await ref
        .watch(cmsPageLayoutRemoteDataSourceProvider)
        .fetch(page: page, locale: AppConfig.storeLocale);
    return CmsPageLayout.fromJson(json);
  } finally {
    // Do not invalidate an initial/refresh request before its response arrives.
    // Each completed read gets a full interval, including slower connections.
    if (ref.mounted) {
      refreshTimer = Timer(const Duration(seconds: 15), () {
        if (ref.mounted) ref.invalidateSelf();
      });
    }
  }
});
