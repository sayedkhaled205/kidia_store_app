/// Supported wallet payment providers.
enum KashierWalletProvider {
  /// Vodafone Cash mobile wallet.
  vodafoneCash,

  /// Other/generic wallet provider.
  other;

  /// Display name in English.
  String get displayNameEn => switch (this) {
        KashierWalletProvider.vodafoneCash => 'Vodafone Cash',
        KashierWalletProvider.other => 'Mobile Wallet',
      };

  /// Display name in Arabic.
  String get displayNameAr => switch (this) {
        KashierWalletProvider.vodafoneCash => 'فودافون كاش',
        KashierWalletProvider.other => 'محفظة إلكترونية',
      };
}
