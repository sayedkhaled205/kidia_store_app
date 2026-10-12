import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cms_page_layout_providers.dart';

/// The Kids preset shares its account, authentication and cart presentation.
/// Commerce operations continue to use their existing controllers.
final compactFamilyProvider = Provider<bool>((ref) {
  return ref.watch(cmsPageLayoutProvider('account')).value
          ?.element('account_menu').boolean('compact_family', false) ?? false;
});
