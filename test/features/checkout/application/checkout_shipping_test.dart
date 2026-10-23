import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/cart/data/models/cart_model.dart';
import 'package:mobishop_store_app/features/cart/data/network/cart_token_store.dart';
import 'package:mobishop_store_app/features/cart/domain/entities/cart.dart';
import 'package:mobishop_store_app/features/checkout/application/checkout_controller.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_address.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_state.dart';
import 'package:mobishop_store_app/features/checkout/domain/entities/checkout_field_definition.dart';
import 'package:mobishop_store_app/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:mobishop_store_app/features/checkout/data/network/checkout_api_transport.dart';
import 'package:mobishop_store_app/features/checkout/data/repositories/store_api_checkout_repository.dart';
import 'package:mobishop_store_app/features/checkout/data/models/checkout_field_normalizer.dart';
import 'package:mobishop_store_app/features/checkout/presentation/checkout_screen.dart';
import '../support/checkout_test_data.dart';

Cart quote({String price='5500', String rate='flat_rate:1', bool calculated=true, bool available=true, List<String> gateways=const ['card','cod']}) {
  final json=checkoutCartJson(paymentMethods: gateways, totalPrice: (17500+int.parse(price)).toString());
  json['has_calculated_shipping']=calculated;
  (json['totals'] as Map)['total_shipping']=price;
  json['shipping_rates']=available ? [{ 'package_id':0, 'name':'Delivery', 'shipping_rates':[
    for(final id in ['flat_rate:1','flat_rate:2']) {
      'rate_id':id,'name':id=='flat_rate:1'?'Standard delivery':'Outer city delivery',
      'price':id=='flat_rate:1'?'5500':'6000', 'taxes':'0', 'selected':id==rate,
      'currency_code':'USD','currency_symbol':r'$', 'currency_minor_unit':2,
    },
  ]}] : [];
  return CartModel.fromJson(json).toEntity();
}
class ShippingRepository extends FakeCheckoutRepository implements CheckoutShippingRepository {
  ShippingRepository() : super(state: CheckoutState(cart: quote()));
  Future<Cart> Function(CheckoutAddress)? onQuote;
  Future<Cart> Function(int,String)? onSelect;
  final destinations=<CheckoutAddress>[];
  int selections=0;
  @override Future<Cart> quoteShipping({required CheckoutAddress billingAddress, required CheckoutAddress shippingAddress}) async {
    destinations.add(shippingAddress);
    return onQuote==null ? state.cart : onQuote!(shippingAddress);
  }
  @override Future<Cart> selectShippingRate({required int packageId, required String rateId}) async {
    selections++;
    return onSelect==null ? quote(price:'6000',rate:rateId,gateways:['card']) : onSelect!(packageId,rateId);
  }
}
class ShippingTransport extends FakeCheckoutTransport implements CheckoutShippingTransport {
  int? packageId;
  String? rateId;
  @override Future<CheckoutApiResponse> selectShippingRate({required String cartToken,required int packageId,required String rateId}) async {
    this.packageId=packageId;this.rateId=rateId;
    return CheckoutApiResponse(data: checkoutCartJson());
  }
}
void main() {
  test('governorate quotes before customer names and street are complete',() async {
    final repo=ShippingRepository();
    final controller=CheckoutController(repository:repo);addTearDown(controller.dispose);
    await controller.load();
    controller.updateBillingAddress(const CheckoutAddress(country:'EG',state:'EGC'));
    await controller.refreshShipping();
    expect(repo.destinations.single.state,'EGC');
    expect(repo.destinations.single.firstName,isEmpty);
    expect(controller.cart!.totals.shippingMinor,'5500');
    expect(controller.shippingReady,isTrue);
    expect(await controller.submit(),isNull);expect(repo.submitCalls,0);
  });
  test('late old address response cannot re-enable ordering or replace newest quote',() async {
    final repo=ShippingRepository();final first=Completer<Cart>();final second=Completer<Cart>();
    repo.onQuote=(address)=>address.state=='EGC'?first.future:second.future;
    final controller=CheckoutController(repository:repo);addTearDown(controller.dispose);
    await controller.load();controller.setFieldValue('billing_state','EGC');
    final update=controller.refreshShipping();await Future<void>.delayed(Duration.zero);
    controller.setFieldValue('billing_state','EGALX');
    first.complete(quote(price:'5500'));
    await Future<void>.delayed(Duration.zero);
    expect(controller.canSubmit,isFalse);expect(controller.shippingQuoteCurrent,isFalse);
    second.complete(quote(price:'4000'));await update;
    expect(controller.cart!.totals.shippingMinor,'4000');expect(repo.destinations.last.state,'EGALX');
  });
  test('selected rate refreshes total and removes ineligible COD without dispatching an order',() async {
    final repo=ShippingRepository();final controller=CheckoutController(repository:repo);addTearDown(controller.dispose);
    await controller.load();await controller.refreshShipping();controller.setPaymentMethod('cod');
    await controller.selectShippingRate(0,'flat_rate:2');
    expect(controller.cart!.totals.shippingMinor,'6000');expect(controller.paymentMethodIds,['card']);
    expect(controller.paymentMethodId,'card');expect(repo.selections,1);expect(repo.submitCalls,0);
    await controller.selectShippingRate(3,'fabricated');expect(repo.selections,1);
  });
  test('no shipping or failed refresh keeps confirmation disabled and retry recovers',() async {
    final repo=ShippingRepository()..onQuote=(_)=>Future.value(quote(available:false));
    final controller=CheckoutController(repository:repo);addTearDown(controller.dispose);
    await controller.load();await controller.refreshShipping();expect(controller.canSubmit,isFalse);
    repo.onQuote=(_)=>Future.error(const CheckoutRepositoryException(kind:CheckoutFailureKind.connection,message:'Offline'));
    await controller.refreshShipping();expect(controller.shippingQuoteCurrent,isFalse);expect(controller.canSubmit,isFalse);
    repo.onQuote=(_)=>Future.value(quote());await controller.refreshShipping();expect(controller.canSubmit,isTrue);
  });
  test('shipping mutation cannot race order confirmation',() async {
    final repo=ShippingRepository();final selection=Completer<Cart>();repo.onSelect=(_,_)=>selection.future;
    final controller=CheckoutController(repository:repo);addTearDown(controller.dispose);
    await controller.load();await controller.refreshShipping();controller.setPaymentMethod('cod');
    final updating=controller.selectShippingRate(0,'flat_rate:2');
    expect(controller.canSubmit,isFalse);expect(await controller.submit(),isNull);expect(repo.submitCalls,0);
    selection.complete(quote(price:'6000',rate:'flat_rate:2'));await updating;
  });
  test('quote payload preserves blank destination instead of invented postcode or incomplete identity',() async {
    final transport=ShippingTransport();final token=MemoryCartTokenStore()..write('cart-test-token');
    final repo=StoreApiCheckoutRepository(cartRepository:FakeCheckoutCartRepository(cart:quote()),transport:transport,cartTokenStore:token);
    await repo.quoteShipping(billingAddress:const CheckoutAddress(country:'US',state:'CA'),shippingAddress:const CheckoutAddress(country:'US',state:'CA'));
    final address=transport.customerBodies.single['shipping_address'] as Map;
    expect(address['postcode'],'');expect(address.containsKey('first_name'),isFalse);
    expect(address['country'],'US');expect(transport.calls,0);
    await repo.selectShippingRate(packageId:0,rateId:'flat_rate:2');expect(transport.rateId,'flat_rate:2');
  });
  test('international schema retains email, postcode and country; changing country clears old region',() async {
    final fields=CheckoutFieldNormalizer.normalize([
      CheckoutFieldDefinition(key:'billing_country',group:CheckoutFieldGroup.billing,type:CheckoutFieldType.select,label:'Country',required:true,options:{'US':'United States','CA':'Canada'},defaultValue:'US'),
      CheckoutFieldDefinition(key:'billing_postcode',group:CheckoutFieldGroup.billing,type:CheckoutFieldType.text,label:'ZIP',required:true),
      CheckoutFieldDefinition(key:'billing_email',group:CheckoutFieldGroup.billing,type:CheckoutFieldType.email,label:'Email',required:true),
      CheckoutFieldDefinition(key:'billing_state',group:CheckoutFieldGroup.billing,type:CheckoutFieldType.select,label:'State',optionsByCountry:{'US':{'CA':'California'},'CA':{'ON':'Ontario'}}),
    ],{'defaults':{'country':'US'}});
    expect(fields.where((f)=>f.isVisible).length,4);
    final controller=CheckoutController(repository:FakeCheckoutRepository(state:CheckoutState(cart:quote(),fieldDefinitions:fields)));addTearDown(controller.dispose);
    await controller.load();controller.setFieldValue('billing_country','US');controller.setFieldValue('billing_state','CA');controller.setFieldValue('billing_postcode','94107');
    controller.setFieldValue('billing_country','CA');
    expect(controller.billingAddress.state,'');expect(controller.billingAddress.postcode,'');
    expect(controller.fieldsFor(CheckoutFieldGroup.billing).singleWhere((f)=>f.key=='billing_state').options,{'ON':'Ontario'});
  });
  testWidgets('real shipping choices and unavailable quote are visible in checkout', (tester) async {
    final repo=ShippingRepository();
    await tester.pumpWidget(MaterialApp(home:CheckoutScreen(repository:repo)));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds:600));
    await tester.ensureVisible(find.byKey(const Key('checkout-payment-shipping-0-flat_rate:2')));
    expect(find.textContaining('Outer city delivery'),findsOneWidget);
    await tester.tap(find.byKey(const Key('checkout-payment-shipping-0-flat_rate:2')));await tester.pumpAndSettle();
    expect(repo.selections,1);expect(repo.submitCalls,0);
  });
}
