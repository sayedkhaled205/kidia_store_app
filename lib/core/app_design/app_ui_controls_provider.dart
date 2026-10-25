import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/page_builder/presentation/providers/cms_page_layout_providers.dart';
import 'app_ui_controls.dart';

final appUiControlsProvider = Provider<AppUiControls>((ref) {
  final home = ref.watch(cmsPageLayoutProvider('home')).value;
  return AppUiControls.fromJson(home?.settings['ui_controls_v1']);
});
