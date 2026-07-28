class CmsPreviewLayoutBridge {
  const CmsPreviewLayoutBridge._();
  static bool useDemoCatalog = false;

  static Stream<Map<String, dynamic>?> layoutsFor(String page) =>
      const Stream<Map<String, dynamic>?>.empty();

  static Stream<Map<String, dynamic>?> get homeLayouts =>
      const Stream<Map<String, dynamic>?>.empty();

  static Stream<Map<String, dynamic>?> get categorySettings =>
      const Stream<Map<String, dynamic>?>.empty();

  static Stream<String> get homeFocusTargets =>
      const Stream<String>.empty();

  static Stream<double> get homeScrollDeltas =>
      const Stream<double>.empty();

  static Future<Map<String, dynamic>> get demoCatalog =>
      Future<Map<String, dynamic>>.value(
        const <String, dynamic>{'products': <dynamic>[], 'categories': <dynamic>[]},
      );
}
