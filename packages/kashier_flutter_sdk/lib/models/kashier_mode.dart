/// Environment mode for Kashier SDK.
///
/// Controls which Kashier API environment is used for all requests.
enum KashierMode {
  /// Test environment — use for development and testing.
  test,

  /// Live environment — use for production payments.
  live;

  /// The base URL for the Kashier API in this mode.
  String get baseUrl => switch (this) {
        KashierMode.test => 'https://test-api.kashier.io',
        KashierMode.live => 'https://api.kashier.io',
      };

  /// The base URL for the Kashier FEP (payment processing) in this mode.
  String get fepBaseUrl => switch (this) {
        KashierMode.test => 'https://test-fep.kashier.io',
        KashierMode.live => 'https://fep.kashier.io',
      };
}
