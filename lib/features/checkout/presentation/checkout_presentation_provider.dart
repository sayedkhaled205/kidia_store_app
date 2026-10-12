import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cart/presentation/providers/cart_providers.dart';
import '../data/network/checkout_api_transport.dart';
import '../domain/entities/checkout_presentation.dart';

final checkoutPresentationProvider = FutureProvider<CheckoutPresentation>((
  ref,
) async {
  try {
    // Use the same verified store-origin/subdirectory transport as the actual
    // checkout fields. The shared Dio deliberately has no implicit base URL.
    final response = await StoreApiCheckoutTransport(
      storeUri: ref.watch(cartStoreUriProvider),
      dio: ref.watch(cartDioProvider),
    ).loadConfiguration();
    final dynamic data = response.data;
    if (data is Map) {
      return CheckoutPresentation.fromJson(Map<String, dynamic>.from(data));
    }
  } catch (_) {
    // A store on an older plugin version keeps the safe classic layout.
  }
  return const CheckoutPresentation();
});
