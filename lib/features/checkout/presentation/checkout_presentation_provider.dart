import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cart/presentation/providers/cart_providers.dart';
import '../domain/entities/checkout_presentation.dart';

final checkoutPresentationProvider = FutureProvider<CheckoutPresentation>((
  ref,
) async {
  try {
    final response = await ref.watch(cartDioProvider).get<dynamic>(
      '/wp-json/woo-mobile/v1/checkout-config',
      options: Options(
        headers: const <String, String>{'Cache-Control': 'no-cache'},
      ),
    );
    final dynamic data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    if (data is Map) {
      return CheckoutPresentation.fromJson(Map<String, dynamic>.from(data));
    }
  } catch (_) {
    // A store on an older plugin version keeps the safe classic layout.
  }
  return const CheckoutPresentation();
});
