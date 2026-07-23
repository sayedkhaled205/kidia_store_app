class CmsPreviewLayoutBridge {
  const CmsPreviewLayoutBridge._();

  static Stream<Map<String, dynamic>?> layoutsFor(String page) =>
      const Stream<Map<String, dynamic>?>.empty();

  static Stream<Map<String, dynamic>?> get homeLayouts =>
      const Stream<Map<String, dynamic>?>.empty();

  static Stream<Map<String, dynamic>?> get categorySettings =>
      const Stream<Map<String, dynamic>?>.empty();

  static Stream<String> get homeFocusTargets =>
      const Stream<String>.empty();
}
