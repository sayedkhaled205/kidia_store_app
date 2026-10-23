import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/checkout/presentation/merchant_checkout_screen88.dart';

void main() {
  final store = Uri.parse('https://merchant.example/shop');
  final ticket = 'a' * 64;
  Map<String, dynamic> valid() => {
    'protocol': 88,
    'url': 'https://merchant.example/shop/?mobishop-checkout88=1',
    'checkout_url': 'https://merchant.example/shop/check-out/',
    'ticket': ticket,
  };
  test(
    'single-use ticket is a POST body; merchant root supports subdirectories',
    () {
      final result = MerchantCheckoutTicket88.parse(store, valid());
      expect(String.fromCharCodes(result.body), 'ticket=$ticket');
      expect(result.uri.query, 'mobishop-checkout88=1');
      expect(result.uri.toString(), isNot(contains(ticket)));
    },
  );
  for (final url in [
    'http://merchant.example/shop/?mobishop-checkout88=1',
    'https://evil.example/shop/?mobishop-checkout88=1',
    'https://merchant.example@evil.example/shop/?mobishop-checkout88=1',
    'https://merchant.example/shop/wp-admin/?mobishop-checkout88=1',
    'https://merchant.example/shop/?mobishop-checkout88=1&target=evil',
    'https://merchant.example/shop/?mobishop-checkout88=1#x',
  ]) {
    test('rejects unsafe merchant destination $url', () {
      expect(
        () => MerchantCheckoutTicket88.parse(store, {...valid(), 'url': url}),
        throwsFormatException,
      );
    });
  }
  test('rejects missing protocol and malformed ticket', () {
    for (final change in [
      {'protocol': 87},
      {'ticket': ''},
      {'ticket': 'a' * 63},
      {'ticket': '$ticket\n'},
      {'ticket': 4},
      {'checkout_url': 'https://evil.example/checkout/'},
      {'checkout_url': 'https://merchant.example/shop/'},
      {'checkout_url': 'https://merchant.example/shop/checkout/?secret=x'},
    ]) {
      expect(
        () => MerchantCheckoutTicket88.parse(store, {...valid(), ...change}),
        throwsFormatException,
      );
    }
  });
}
