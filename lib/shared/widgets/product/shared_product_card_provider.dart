import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobishop_store_app/features/page_builder/domain/cms_page_layout.dart';
import 'package:mobishop_store_app/features/page_builder/presentation/providers/cms_page_layout_providers.dart';

/// The Catalog card controls are the single published source of appearance.
/// A theme opts in explicitly, preserving existing independent designs.
final sharedProductCardProvider = Provider<CmsPageComponent?>((ref) {
  final layout = ref.watch(cmsPageLayoutProvider('catalog')).value;
  if (layout == null) return null;
  final card = layout.element('product_grid');
  return card.boolean('share_style_across_app', false) ? card : null;
});
