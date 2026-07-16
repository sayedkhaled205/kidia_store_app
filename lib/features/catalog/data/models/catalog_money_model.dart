import 'package:kidia_store_app/features/catalog/data/models/catalog_json.dart';
import 'package:kidia_store_app/features/catalog/domain/entities/catalog_money.dart';

class CatalogMoneyModel extends CatalogMoney {
  const CatalogMoneyModel({
    required super.currencyCode,
    required super.currencyMinorUnit,
    required super.priceMinor,
    super.currencySymbol,
    super.currencyPrefix,
    super.currencySuffix,
    super.regularPriceMinor,
    super.salePriceMinor,
    super.priceRange,
  });

  factory CatalogMoneyModel.fromJson(dynamic value) {
    final Map<String, dynamic> json =
        CatalogJson.object(value) ?? const <String, dynamic>{};
    final Map<String, dynamic>? range = CatalogJson.object(json['price_range']);

    final String minimum = CatalogJson.minorAmount(
      range?['min_amount'] ?? range?['minimum'] ?? range?['min_price'],
    );
    final String maximum = CatalogJson.minorAmount(
      range?['max_amount'] ?? range?['maximum'] ?? range?['max_price'],
    );
    final int rawMinorUnit = CatalogJson.integer(
      json['currency_minor_unit'],
      fallback: 2,
    );
    final int minorUnit = rawMinorUnit < 0
        ? 0
        : rawMinorUnit > 8
        ? 8
        : rawMinorUnit;

    return CatalogMoneyModel(
      currencyCode: CatalogJson.string(json['currency_code']),
      currencySymbol: CatalogJson.string(json['currency_symbol']),
      currencyPrefix: _currencyAffix(json['currency_prefix']),
      currencySuffix: _currencyAffix(json['currency_suffix']),
      currencyMinorUnit: minorUnit,
      priceMinor: CatalogJson.minorAmount(json['price']),
      regularPriceMinor: CatalogJson.minorAmount(json['regular_price']),
      salePriceMinor: CatalogJson.minorAmount(json['sale_price']),
      priceRange: minimum.isNotEmpty && maximum.isNotEmpty
          ? CatalogPriceRange(minimumMinor: minimum, maximumMinor: maximum)
          : null,
    );
  }

  static String _currencyAffix(dynamic value) {
    if (value == null) {
      return '';
    }

    final String affix = value.toString();
    return affix.trim().isEmpty ? '' : affix;
  }
}
