import '../../page_builder/domain/cms_page_layout.dart';

/// A saved builder ratio takes precedence over a subsequently decoded image.
double productGalleryAspectRatio(
  CmsPageComponent settings,
  double? naturalRatio,
) {
  final configured = productGalleryConfiguredRatio(settings);
  if (configured != null) return configured;
  return naturalRatio != null && naturalRatio.isFinite && naturalRatio > 0
      ? naturalRatio.clamp(0.45, 2.4).toDouble()
      : 1;
}

double? productGalleryConfiguredRatio(CmsPageComponent settings) {
  final raw = settings.settings['aspect_ratio'];
  final configured = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (configured != null && configured.isFinite && configured > 0) {
    return configured.clamp(0.6, 1.8).toDouble();
  }
  return null;
}
