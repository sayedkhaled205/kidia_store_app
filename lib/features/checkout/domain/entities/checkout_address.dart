import 'package:kidia_store_app/features/cart/domain/entities/cart_address.dart';

class CheckoutAddress {
  const CheckoutAddress({
    this.firstName = '',
    this.lastName = '',
    this.company = '',
    this.address1 = '',
    this.address2 = '',
    this.city = '',
    this.state = '',
    this.postcode = '',
    this.country = '',
    this.email = '',
    this.phone = '',
  });

  factory CheckoutAddress.fromCartAddress(CartAddress address) {
    return CheckoutAddress(
      firstName: address.firstName,
      lastName: address.lastName,
      company: address.company,
      address1: address.address1,
      address2: address.address2,
      city: address.city,
      state: address.state,
      postcode: address.postcode,
      country: address.country,
      email: address.email,
      phone: address.phone,
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

  CheckoutAddress copyWith({
    String? firstName,
    String? lastName,
    String? company,
    String? address1,
    String? address2,
    String? city,
    String? state,
    String? postcode,
    String? country,
    String? email,
    String? phone,
  }) {
    return CheckoutAddress(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      company: company ?? this.company,
      address1: address1 ?? this.address1,
      address2: address2 ?? this.address2,
      city: city ?? this.city,
      state: state ?? this.state,
      postcode: postcode ?? this.postcode,
      country: country ?? this.country,
      email: email ?? this.email,
      phone: phone ?? this.phone,
    );
  }

  CheckoutAddress trimmed() {
    return CheckoutAddress(
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      company: company.trim(),
      address1: address1.trim(),
      address2: address2.trim(),
      city: city.trim(),
      state: state.trim(),
      postcode: postcode.trim(),
      country: country.trim().toUpperCase(),
      email: email.trim(),
      phone: phone.trim(),
    );
  }
}
