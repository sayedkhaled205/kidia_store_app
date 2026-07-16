import 'package:kidia_store_app/features/cart/data/models/cart_json.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_error.dart';

class CartErrorModel {
  const CartErrorModel({
    required this.code,
    required this.message,
    this.statusCode,
  });

  factory CartErrorModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = CartJson.optionalObject(
      json['data'],
      'error.data',
    );
    return CartErrorModel(
      code: CartJson.text(json['code']),
      message: CartJson.text(json['message']),
      statusCode: CartJson.nullableInteger(data['status'] ?? json['status']),
    );
  }

  final String code;
  final String message;
  final int? statusCode;

  CartError toEntity() =>
      CartError(code: code, message: message, statusCode: statusCode);
}
