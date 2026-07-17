import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/account/data/network/customer_account_api_transport.dart';
import 'package:kidia_store_app/features/account/data/repositories/customer_account_repository_impl.dart';
import 'package:kidia_store_app/features/account/domain/entities/customer_account.dart';
import 'package:kidia_store_app/features/account/domain/repositories/customer_account_repository.dart';

void main() {
  test('parses profile, addresses, support and hides postcode', () async {
    final _FakeAccountTransport transport = _FakeAccountTransport();
    final CustomerAccountRepositoryImpl repository =
        CustomerAccountRepositoryImpl(transport);

    final CustomerAccount account = await repository.getAccount();

    expect(account.profile.email, 'customer@example.com');
    expect(account.billing.valueFor('billing_city'), 'Cairo');
    expect(account.support.email, 'support@example.com');
    expect(account.support.contactUrl?.host, 'shop.example.com');
    final CustomerAddressField postcode = account.addressFields.singleWhere(
      (CustomerAddressField field) => field.key == 'billing_postcode',
    );
    expect(postcode.isVisible, isFalse);
    expect(postcode.required, isFalse);
    expect(postcode.defaultValue, isEmpty);
  });

  test('updates profile and address through WooCommerce transport', () async {
    final _FakeAccountTransport transport = _FakeAccountTransport();
    final CustomerAccountRepositoryImpl repository =
        CustomerAccountRepositoryImpl(transport);

    final CustomerProfile profile = await repository.updateProfile(
      firstName: ' Updated ',
      lastName: 'Customer',
      displayName: 'Updated Customer',
      email: 'updated@example.com',
      phone: ' 01000000000 ',
      alternatePhone: ' 01100000000 ',
    );
    final CustomerAddress address = await repository.updateAddress(
      CustomerAddress(
        type: CustomerAddressType.shipping,
        values: const <String, String>{
          'shipping_address_1': '2 New Street',
        },
      ),
    );

    expect(transport.profileValues?['first_name'], 'Updated');
    expect(transport.profileValues?['phone'], '01000000000');
    expect(transport.profileValues?['alternate_phone'], '01100000000');
    expect(profile.email, 'updated@example.com');
    expect(transport.addressType, CustomerAddressType.shipping);
    expect(address.valueFor('shipping_address_1'), '2 New Street');
  });

  test('accepts WooCommerce international phone formatting after save', () async {
    final CustomerAccountRepositoryImpl repository =
        CustomerAccountRepositoryImpl(
          _FakeAccountTransport(internationalizePhones: true),
        );

    final CustomerProfile profile = await repository.updateProfile(
      firstName: 'Updated',
      lastName: 'Customer',
      displayName: 'Updated Customer',
      email: 'updated@example.com',
      phone: '010694000065',
      alternatePhone: '01155555555',
    );

    expect(profile.phone, '+2010694000065');
    expect(profile.alternatePhone, '00201155555555');
  });

  test('rejects update responses that were not persisted', () async {
    final CustomerAccountRepositoryImpl repository =
        CustomerAccountRepositoryImpl(
          _FakeAccountTransport(persistWrites: false),
        );

    await expectLater(
      repository.updateProfile(
        firstName: 'Updated',
        lastName: 'Customer',
        displayName: 'Updated Customer',
        email: 'updated@example.com',
        phone: '01000000000',
        alternatePhone: '01100000000',
      ),
      throwsA(
        isA<CustomerAccountRepositoryException>().having(
          (CustomerAccountRepositoryException error) => error.kind,
          'kind',
          CustomerAccountFailureKind.invalidResponse,
        ),
      ),
    );

    await expectLater(
      repository.updateAddress(
        CustomerAddress(
          type: CustomerAddressType.shipping,
          values: const <String, String>{
            'shipping_address_1': '2 New Street',
          },
        ),
      ),
      throwsA(
        isA<CustomerAccountRepositoryException>().having(
          (CustomerAccountRepositoryException error) => error.kind,
          'kind',
          CustomerAccountFailureKind.invalidResponse,
        ),
      ),
    );
  });
}

class _FakeAccountTransport implements CustomerAccountApiTransport {
  _FakeAccountTransport({
    this.persistWrites = true,
    this.internationalizePhones = false,
  });

  final bool persistWrites;
  final bool internationalizePhones;
  Map<String, String>? profileValues;
  CustomerAddressType? addressType;

  @override
  Future<Map<String, dynamic>> fetchAccount() async {
    return <String, dynamic>{
      'profile': <String, dynamic>{
        'id': 7,
        'email': 'customer@example.com',
        'first_name': 'Kidia',
        'last_name': 'Customer',
        'display_name': 'Kidia Customer',
        'phone': '01000000000',
        'alternate_phone': '01100000000',
      },
      'billing': <String, dynamic>{
        'billing_address_1': '1 Test Street',
        'billing_city': 'Cairo',
        'billing_country': 'EG',
      },
      'shipping': <String, dynamic>{},
      'support': <String, dynamic>{
        'email': 'support@example.com',
        'phone': '01000000000',
        'whatsapp': '201000000000',
        'contact_url': 'https://shop.example.com/contact-us/',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> fetchAddressConfig() async {
    return <String, dynamic>{
      'fields': <dynamic>[
        <String, dynamic>{
          'key': 'billing_address_1',
          'group': 'billing',
          'type': 'text',
          'label': 'Address',
          'required': true,
          'priority': 50,
        },
        <String, dynamic>{
          'key': 'billing_postcode',
          'group': 'billing',
          'type': 'text',
          'label': 'Postcode',
          'required': true,
          'priority': 90,
          'default': '12345',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> updateProfile(Map<String, String> values) async {
    profileValues = values;
    Map<String, String> stored = persistWrites
        ? values
        : <String, String>{...values, 'display_name': 'Old name'};
    if (persistWrites && internationalizePhones) {
      stored = <String, String>{
        ...stored,
        'phone': '+20${values['phone']?.substring(1)}',
        'alternate_phone': '0020${values['alternate_phone']?.substring(1)}',
      };
    }
    return <String, dynamic>{
      'profile': <String, dynamic>{
        'id': 7,
        'email': stored['email'],
        'first_name': stored['first_name'],
        'last_name': stored['last_name'],
        'display_name': stored['display_name'],
        'phone': stored['phone'],
        'alternate_phone': stored['alternate_phone'],
      },
    };
  }

  @override
  Future<Map<String, dynamic>> updateAddress(
    CustomerAddressType type,
    Map<String, String> values,
  ) async {
    addressType = type;
    return <String, dynamic>{
      'address': persistWrites
          ? values
          : <String, String>{
              ...values,
              'shipping_address_1': 'Old address',
            },
    };
  }
}
