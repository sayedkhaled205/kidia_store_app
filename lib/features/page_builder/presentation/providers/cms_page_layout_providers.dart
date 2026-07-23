import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/features/home/presentation/providers/home_providers.dart';
import 'package:kidia_store_app/features/page_builder/data/cms_page_layout_remote_data_source.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:kidia_store_app/features/page_builder/presentation/providers/cms_preview_layout_bridge.dart';

final cmsPreviewLayoutJsonProvider =
    StreamProvider.family<Map<String, dynamic>?, String>(
      (Ref ref, String page) => CmsPreviewLayoutBridge.layoutsFor(page),
    );

final Provider<CmsPageLayoutRemoteDataSource>
cmsPageLayoutRemoteDataSourceProvider = Provider<CmsPageLayoutRemoteDataSource>(
  (Ref ref) {
    return CmsPageLayoutRemoteDataSource(ref.watch(homeDioProvider));
  },
);

final cmsPageLayoutProvider = FutureProvider.family<CmsPageLayout, String>((
  Ref ref,
  String page,
) async {
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
  final Timer refreshTimer = Timer(
    const Duration(seconds: 5),
    ref.invalidateSelf,
  );
  ref.onDispose(refreshTimer.cancel);
  if (AppConfig.useMockHomeLayout) {
    return CmsPageLayout.fallback(page);
  }
  final Map<String, dynamic> json = await ref
      .watch(cmsPageLayoutRemoteDataSourceProvider)
      .fetch(page: page, locale: AppConfig.storeLocale);
  return CmsPageLayout.fromJson(json);
});
