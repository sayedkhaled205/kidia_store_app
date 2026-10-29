class CmsPreviewLayoutBridge {
  const CmsPreviewLayoutBridge._();
  static bool useDemoCatalog = false;
  static bool useLiveCatalog = false;

  static void editElement(String page, String target, String? item) {}

  static Map<String, dynamic>? get currentHomeLayout => null;
  static Future<Map<String, dynamic>> fetchAuthConfiguration() =>
      Future.error(UnsupportedError('Authentication preview is web-only.'));
  static Future<Map<String, dynamic>> fetchCheckoutConfiguration() =>
      Future.error(UnsupportedError('Checkout preview is web-only.'));
  static int get catalogRevision => 0;
  static Stream<int> get catalogChanges => const Stream<int>.empty();
  static Stream<Map<String, dynamic>?> get identitySettings =>
      const Stream<Map<String, dynamic>?>.empty();

  static Future<Map<String, dynamic>> fetchCatalogPage(
    Map<String, dynamic> query,
  ) => Future<Map<String, dynamic>>.error(
    UnsupportedError('Live catalog preview is only available on web.'),
  );

  static Stream<Map<String, dynamic>?> layoutsFor(String page) =>
      const Stream<Map<String, dynamic>?>.empty();

  static Stream<Map<String, dynamic>?> get homeLayouts =>
      const Stream<Map<String, dynamic>?>.empty();

  static Stream<Map<String, dynamic>?> get categorySettings =>
      const Stream<Map<String, dynamic>?>.empty();

  static Stream<Map<String, dynamic>?> get splashSettings =>
      const Stream<Map<String, dynamic>?>.empty();

  static Stream<String> get homeFocusTargets => const Stream<String>.empty();

  static Stream<double> get homeScrollDeltas => const Stream<double>.empty();

  static Future<Map<String, dynamic>> get demoCatalog =>
      Future<Map<String, dynamic>>.value(const <String, dynamic>{
        'products': <dynamic>[],
        'categories': <dynamic>[],
      });

  static Future<Map<String, dynamic>> get splashConfig =>
      Future<Map<String, dynamic>>.value(const <String, dynamic>{});
}
