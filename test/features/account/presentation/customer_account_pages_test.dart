import '../../../support/viewport_rotation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/account/domain/entities/customer_account.dart';
import 'package:mobishop_store_app/features/account/domain/repositories/customer_account_repository.dart';
import 'package:mobishop_store_app/features/account/presentation/customer_profile_screen.dart';
import 'package:mobishop_store_app/features/account/presentation/customer_support_screen.dart';
import 'package:mobishop_store_app/features/account/presentation/providers/customer_account_providers.dart';
import 'package:mobishop_store_app/features/account/presentation/saved_addresses_screen.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_session.dart';
import 'package:mobishop_store_app/features/auth/domain/entities/auth_user.dart';
import 'package:mobishop_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobishop_store_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobishop_store_app/features/cart/presentation/providers/cart_state_providers.dart';

void main() {
  viewportRotationTests('Address editor', (tester,size) async {
    await tester.pumpWidget(_app(const SavedAddressesScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('close-address-editor')), findsOneWidget);
  });
  viewportRotationTests('Profile', (tester,size) => tester.pumpWidget(_app(const CustomerProfileScreen())));
  viewportRotationTests('Addresses', (tester,size) => tester.pumpWidget(_app(const SavedAddressesScreen())));
  viewportRotationTests('Support', (tester,size) => tester.pumpWidget(_app(const CustomerSupportScreen())));
  testWidgets('text country rejects malformed codes and saves uppercase', (
    tester,
  ) async {
    final repo = _ManualCountryRepository();
    await tester.pumpWidget(
      _app(const SavedAddressesScreen(), repository: repo),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('تعديل'));
    await tester.pumpAndSettle();
    final country = find.byKey(const Key('customer-address-billing_country'));
    final save = find.byKey(const Key('save-customer-address'));
    for (final invalid in ['U', 'United States']) {
      await tester.enterText(country, invalid);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(repo.saved, isNull);
    }
    await tester.enterText(country, 'us');
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(repo.saved?.values['billing_country'], 'US');
  });
  testWidgets(
    'country change resets dependent fields and preserves typed street',
    (tester) async {
      final repo = _InternationalAccountRepository();
      await tester.pumpWidget(
        _app(const SavedAddressesScreen(), repository: repo),
      );
      await tester.pumpAndSettle();
      expect(find.text('90210'), findsOneWidget);
      await tester.tap(find.text('تعديل'));
      await tester.pumpAndSettle();
      final street = find.byKey(
        const Key('customer-address-billing_address_1'),
      );
      final country = find.byKey(const Key('customer-address-billing_country'));
      final state = find.byKey(const Key('customer-address-billing_state'));
      final postcode = find.byKey(
        const Key('customer-address-billing_postcode'),
      );
      await tester.enterText(street, 'Typed street');
      await tester.tap(country);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Canada').last);
      await tester.pumpAndSettle();
      expect(tester.widget<TextFormField>(street).initialValue, 'Typed street');
      expect(tester.widget<TextFormField>(postcode).initialValue, '');
      final select = tester.widget<DropdownButtonFormField<String>>(state);
      expect(select.initialValue, isNull);
      await tester.tap(state);
      await tester.pumpAndSettle();
      expect(find.text('California'), findsNothing);
      await tester.tap(find.text('Ontario').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('save-customer-address')),
      );
      await tester.tap(find.byKey(const Key('save-customer-address')));
      await tester.pumpAndSettle();
      expect(
        repo.saved,
        isNull,
        reason: 'Required postcode must block empty save',
      );
      await tester.ensureVisible(postcode);
      await tester.enterText(postcode, 'K1A 0B1');
      await tester.ensureVisible(
        find.byKey(const Key('save-customer-address')),
      );
      await tester.tap(find.byKey(const Key('save-customer-address')));
      await tester.pumpAndSettle();
      expect(repo.saved?.values, containsPair('billing_country', 'CA'));
      expect(repo.saved?.values, containsPair('billing_state', 'ON'));
      expect(repo.saved?.values, containsPair('billing_postcode', 'K1A 0B1'));
      expect(
        repo.saved?.values,
        containsPair('billing_address_1', 'Typed street'),
      );
    },
  );
  testWidgets('saved addresses use store fields without showing postcode', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(const SavedAddressesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('العناوين المحفوظة'), findsOneWidget);
    expect(find.text('عنوان الشحن'), findsOneWidget);
    expect(find.text('عنوان الفاتورة'), findsNothing);
    expect(find.byKey(const Key('shipping-address-card')), findsOneWidget);
    expect(find.text('1 Test Street'), findsOneWidget);
    expect(find.text('01000000000'), findsOneWidget);
    expect(find.text('+201000000000'), findsNothing);
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
    final EditableText phoneEditor = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('customer-address-billing_phone')),
        matching: find.byType(EditableText),
      ),
    );
    expect(phoneEditor.controller.text, '01000000000');
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
    final TextFormField phone = tester.widget<TextFormField>(
      find.byKey(const Key('profile-phone')),
    );
    expect(phone.controller?.text, '01000000000');
    expect(find.byKey(const Key('profile-alternate-phone')), findsNothing);
    expect(find.byKey(const Key('save-customer-profile')), findsOneWidget);
    for (final String key in <String>[
      'profile-first-name',
      'profile-last-name',
      'profile-display-name',
      'profile-phone',
      'profile-email',
    ]) {
      expect(
        Directionality.of(tester.element(find.byKey(Key(key)))),
        TextDirection.rtl,
      );
    }
  });

  testWidgets('customer service shows the two official MobiShop contacts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_app(const CustomerSupportScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('support-action-whatsapp')), findsOneWidget);
    expect(find.byKey(const Key('support-action-email')), findsOneWidget);
    expect(find.byKey(const Key('support-action-phone')), findsNothing);
    expect(find.byKey(const Key('support-action-website')), findsNothing);
    expect(find.text('01208846445'), findsOneWidget);
    expect(find.text('support@mobishopstore.com'), findsOneWidget);
    expect(find.byType(Card), findsNWidgets(2));
  });
}

Widget _app(Widget home, {CustomerAccountRepository? repository}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
      customerAccountRepositoryProvider.overrideWithValue(
        repository ?? const _FakeCustomerAccountRepository(),
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

class _InternationalAccountRepository extends _FakeCustomerAccountRepository {
  CustomerAddress? saved;
  @override
  Future<CustomerAccount> getAccount() async => CustomerAccount(
    profile: _account.profile,
    support: _account.support,
    shipping: _account.shipping,
    billing:
        saved ??
        CustomerAddress(
          type: CustomerAddressType.billing,
          values: {
            'billing_address_1': 'Old street',
            'billing_country': 'US',
            'billing_state': 'CA',
            'billing_postcode': '90210',
          },
        ),
    addressFields: [
      CustomerAddressField(
        key: 'billing_address_1',
        type: CustomerAddressFieldType.text,
        addressType: CustomerAddressType.billing,
        label: 'Address',
        required: true,
      ),
      CustomerAddressField(
        key: 'billing_country',
        type: CustomerAddressFieldType.select,
        addressType: CustomerAddressType.billing,
        label: 'Country',
        required: true,
        options: {'US': 'United States', 'CA': 'Canada'},
      ),
      CustomerAddressField(
        key: 'billing_state',
        type: CustomerAddressFieldType.select,
        addressType: CustomerAddressType.billing,
        label: 'State',
        required: true,
        optionsByCountry: {
          'US': {'CA': 'California'},
          'CA': {'ON': 'Ontario'},
        },
      ),
      CustomerAddressField(
        key: 'billing_postcode',
        type: CustomerAddressFieldType.text,
        addressType: CustomerAddressType.billing,
        label: 'Postcode',
        required: true,
      ),
    ],
  );
  @override
  Future<CustomerAddress> updateAddress(CustomerAddress address) async {
    saved = address;
    return address;
  }
}

class _ManualCountryRepository extends _InternationalAccountRepository {
  @override
  Future<CustomerAccount> getAccount() async {
    final account = await super.getAccount();
    return CustomerAccount(
      profile: account.profile,
      support: account.support,
      billing: account.billing,
      shipping: account.shipping,
      addressFields: [
        CustomerAddressField(
          key: 'billing_country',
          type: CustomerAddressFieldType.text,
          addressType: CustomerAddressType.billing,
          label: 'Country',
          required: true,
        ),
      ],
    );
  }
}

final CustomerAccount _account = CustomerAccount(
  profile: const CustomerProfile(
    id: 7,
    email: 'customer@example.com',
    firstName: 'MobiShop',
    lastName: 'Customer',
    displayName: 'MobiShop Customer',
    phone: '01000000000',
    alternatePhone: '01100000000',
  ),
  billing: CustomerAddress(
    type: CustomerAddressType.billing,
    values: <String, String>{
      'billing_first_name': 'MobiShop',
      'billing_address_1': '1 Test Street',
      'billing_city': 'Cairo',
      'billing_phone': '+201000000000',
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
      key: 'billing_phone',
      type: CustomerAddressFieldType.telephone,
      addressType: CustomerAddressType.billing,
      label: 'رقم الهاتف',
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
    required String phone,
    required String alternatePhone,
  }) async {
    return CustomerProfile(
      id: 7,
      email: email,
      firstName: firstName,
      lastName: lastName,
      displayName: displayName,
      phone: phone,
      alternatePhone: alternatePhone,
    );
  }
}

// This profile fixture belongs to an authenticated customer, matching the
// production session/account identity guard. It never restores real storage.
class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthSession?> restoreSession() async => AuthSession(
    token: 'owned-widget-fixture-session',
    expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
    user: const AuthUser(id: 7, email: 'customer@example.com'),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected widget auth operation');
}

