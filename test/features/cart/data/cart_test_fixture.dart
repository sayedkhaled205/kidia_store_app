Map<String, dynamic> cartJsonFixture({
  String totalPrice = '8256',
  int itemsCount = 1,
}) {
  final Map<String, dynamic> currency = <String, dynamic>{
    'currency_code': 'KWD',
    'currency_symbol': 'د.ك',
    'currency_minor_unit': 3,
    'currency_decimal_separator': '.',
    'currency_thousand_separator': ',',
    'currency_prefix': '',
    'currency_suffix': ' د.ك',
  };

  return <String, dynamic>{
    'items': <dynamic>[
      <String, dynamic>{
        'key': 'cart-key-1',
        'id': 38,
        'quantity': 1,
        'quantity_limits': <String, dynamic>{
          'minimum': 1,
          'maximum': 10,
          'multiple_of': 1,
          'editable': true,
        },
        'name': 'Test product',
        'short_description': '<p>Short description</p>',
        'sku': 'SKU-38',
        'low_stock_remaining': 2,
        'backorders_allowed': false,
        'show_backorder_badge': false,
        'sold_individually': false,
        'images': <dynamic>[
          <String, dynamic>{
            'id': 61,
            'src': 'https://cdn.example.com/product.jpg',
            'thumbnail': 'https://cdn.example.com/product-thumb.jpg',
            'alt': 'Product',
          },
        ],
        'variation': <dynamic>[
          <String, dynamic>{'attribute': 'pa_color', 'value': 'blue'},
        ],
        'prices': <String, dynamic>{
          'price': '1800',
          'regular_price': '2000',
          'sale_price': '1800',
          ...currency,
        },
        'totals': <String, dynamic>{
          'line_subtotal': '1800',
          'line_subtotal_tax': '180',
          'line_total': '1530',
          'line_total_tax': '153',
          ...currency,
        },
      },
    ],
    'coupons': <dynamic>[
      <String, dynamic>{
        'code': 'save10',
        'discount_type': 'percent',
        'totals': <String, dynamic>{
          'total_discount': '100',
          'total_discount_tax': '10',
          ...currency,
        },
      },
    ],
    'totals': <String, dynamic>{
      'total_items': '7300',
      'total_items_tax': '730',
      'total_fees': '0',
      'total_fees_tax': '0',
      'total_discount': '1095',
      'total_discount_tax': '110',
      'total_shipping': '1300',
      'total_shipping_tax': '130',
      'total_price': totalPrice,
      'total_tax': '751',
      ...currency,
    },
    'shipping_address': <String, dynamic>{
      'first_name': 'Test',
      'last_name': 'Shopper',
      'address_1': 'Street 1',
      'city': 'Cairo',
      'country': 'EG',
      'phone': '1000000000',
    },
    'billing_address': <String, dynamic>{
      'first_name': 'Test',
      'last_name': 'Shopper',
      'address_1': 'Street 1',
      'city': 'Cairo',
      'country': 'EG',
      'email': 'shopper@example.com',
      'phone': '1000000000',
    },
    'items_count': itemsCount,
    'items_weight': 0,
    'needs_payment': true,
    'needs_shipping': true,
    'has_calculated_shipping': false,
    'payment_methods': <String>['cod'],
    'errors': <dynamic>[],
  };
}
