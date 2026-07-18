import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kidia_store_app/core/config/app_config.dart';
import 'package:kidia_store_app/features/home/presentation/providers/home_providers.dart';
import 'package:kidia_store_app/features/page_builder/data/cms_page_layout_remote_data_source.dart';
import 'package:kidia_store_app/features/page_builder/domain/cms_page_layout.dart';

final Provider<CmsPageLayoutRemoteDataSource> cmsPageLayoutRemoteDataSourceProvider =
    Provider<CmsPageLayoutRemoteDataSource>((Ref ref) {
      return CmsPageLayoutRemoteDataSource(ref.watch(homeDioProvider));
    });

final FutureProviderFamily<CmsPageLayout, String> cmsPageLayoutProvider =
    FutureProvider.autoDispose.family<CmsPageLayout, String>(
      (Ref ref, String page) async {
        if (AppConfig.useMockHomeLayout) {
          return CmsPageLayout.fallback(page);
        }
        final Map<String, dynamic> json = await ref
            .watch(cmsPageLayoutRemoteDataSourceProvider)
            .fetch(page: page, locale: AppConfig.storeLocale);
        return CmsPageLayout.fromJson(json);
      },
    );
