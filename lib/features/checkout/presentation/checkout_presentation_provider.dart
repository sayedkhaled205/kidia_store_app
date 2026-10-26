import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_design/app_design_providers58.dart';
import '../../../core/config/app_config.dart';
import '../../../core/commerce/commerce_connection.dart';

import '../../cart/presentation/providers/cart_providers.dart';
import '../data/network/checkout_api_transport.dart';
import '../domain/entities/checkout_presentation.dart';

final checkoutPresentationProvider =
    FutureProvider.autoDispose<CheckoutPresentation>((ref) async {
      final published = ref
          .watch(portableAppDesign58Provider)
          ?.pageLayout('home')
          .settings['checkout_presentation_v1'];
      if (published is Map &&
          CheckoutDesign.values.any(
            (value) => value.apiValue == published['design'],
          )) {
        return CheckoutPresentation.fromJson(
          Map<String, dynamic>.from(published),
        );
      }
      // Foreign checkouts retain their own platform transport. A public design
      // must never instantiate Woo checkout to obtain presentation defaults.
      if (AppConfig.commercePlatform != CommercePlatform.wooCommerce) {
        return const CheckoutPresentation();
      }
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
