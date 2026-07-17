import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/account/domain/entities/customer_account.dart';
import 'package:kidia_store_app/features/account/domain/repositories/customer_account_repository.dart';
import 'package:kidia_store_app/features/account/presentation/customer_profile_screen.dart';
import 'package:kidia_store_app/features/account/presentation/customer_support_screen.dart';
import 'package:kidia_store_app/features/account/presentation/providers/customer_account_providers.dart';
import 'package:kidia_store_app/features/account/presentation/saved_addresses_screen.dart';
import 'package:kidia_store_app/features/cart/presentation/providers/cart_state_providers.dart';

void main() {
  testWidgets('saved addresses use store fields without showing postcode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(const SavedAddressesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('العناوين المحفوظة'), findsOneWidget);
    expect(find.text('1 Test Street'), findsOneWidget);
    await tester.tap(find.text('تعديل'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('customer-address-billing_address_1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('customer-address-billing_postcode')),
      findsNothing,
    );
  });

  testWidgets('profile page loads the real customer fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(const CustomerProfileScreen()));
    await tester.pumpAndSettle();

    expect(find.text('بيانات حسابي'), findsOneWidget);
    final TextFormField email = tester.widget<TextFormField>(
      find.byKey(const Key('profile-email')),
    );
    expect(email.controller?.text, 'customer@example.com');
    expect(find.byKey(const Key('save-customer-profile')), findsOneWidget);
  });

  testWidgets('customer service shows only configured contact methods', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(const CustomerSupportScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('support-action-whatsapp')), findsOneWidget);
    expect(find.byKey(const Key('support-action-phone')), findsOneWidget);
    expect(find.byKey(const Key('support-action-email')), findsOneWidget);
    expect(find.byKey(const Key('support-action-website')), findsOneWidget);
  });
}

Widget _app(Widget home) {
  return ProviderScope(
    overrides: [
      customerAccountRepositoryProvider.overrideWithValue(
        const _FakeCustomerAccountRepository(),
      ),
      cartBadgeCountProvider.overrideWithValue(0),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    ),
  );
}

final CustomerAccount _account = CustomerAccount(
  profile: const CustomerProfile(
    id: 7,
    email: 'customer@example.com',
    firstName: 'Kidia',
    lastName: 'Customer',
    displayName: 'Kidia Customer',
  ),
  billing: CustomerAddress(
    type: CustomerAddressType.billing,
    values: <String, String>{
      'billing_first_name': 'Kidia',
      'billing_address_1': '1 Test Street',
      'billing_city': 'Cairo',
    },
  ),
  shipping: CustomerAddress(type: CustomerAddressType.shipping),
  support: CustomerSupportDetails(
    email: 'support@example.com',
    phone: '01000000000',
    whatsapp: '201000000000',
    contactUrl: Uri.parse('https://shop.example.com/contact-us/'),
  ),
  addressFields: <CustomerAddressField>[
    CustomerAddressField(
      key: 'billing_address_1',
      type: CustomerAddressFieldType.text,
      addressType: CustomerAddressType.billing,
      label: 'العنوان',
      required: true,
    ),
    CustomerAddressField(
      key: 'billing_postcode',
      type: CustomerAddressFieldType.hidden,
      addressType: CustomerAddressType.billing,
      label: 'الرقم البريدي',
    ),
  ],
);

class _FakeCustomerAccountRepository implements CustomerAccountRepository {
  const _FakeCustomerAccountRepository();

  @override
  Future<CustomerAccount> getAccount() async => _account;

  @override
  Future<CustomerAddress> updateAddress(CustomerAddress address) async =>
      address;

  @override
  Future<CustomerProfile> updateProfile({
    required String firstName,
    required String lastName,
    required String displayName,
    required String email,
  }) async {
    return CustomerProfile(
      id: 7,
      email: email,
      firstName: firstName,
      lastName: lastName,
      displayName: displayName,
    );
  }
}
