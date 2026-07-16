import 'package:kidia_store_app/features/cart/data/models/cart_json.dart';
import 'package:kidia_store_app/features/cart/domain/entities/cart_address.dart';

class CartAddressModel {
  const CartAddressModel({
    required this.firstName,
    required this.lastName,
    required this.company,
    required this.address1,
    required this.address2,
    required this.city,
    required this.state,
    required this.postcode,
    required this.country,
    required this.email,
    required this.phone,
  });

  factory CartAddressModel.fromJson(Map<String, dynamic> json) {
    return CartAddressModel(
      firstName: CartJson.text(json['first_name']),
      lastName: CartJson.text(json['last_name']),
      company: CartJson.text(json['company']),
      address1: CartJson.text(json['address_1']),
      address2: CartJson.text(json['address_2']),
      city: CartJson.text(json['city']),
      state: CartJson.text(json['state']),
      postcode: CartJson.text(json['postcode']),
      country: CartJson.text(json['country']),
      email: CartJson.text(json['email']),
      phone: CartJson.text(json['phone']),
    );
  }

  final String firstName;
  final String lastName;
  final String company;
  final String address1;
  final String address2;
  final String city;
  final String state;
  final String postcode;
  final String country;
  final String email;
  final String phone;

  CartAddress toEntity() => CartAddress(
    firstName: firstName,
    lastName: lastName,
    company: company,
    address1: address1,
    address2: address2,
    city: city,
    state: state,
    postcode: postcode,
    country: country,
    email: email,
    phone: phone,
  );
}
