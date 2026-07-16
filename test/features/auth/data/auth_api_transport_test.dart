import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/auth/data/network/auth_api_transport.dart';

void main() {
  test('keeps credentials on fixed same-origin mobile auth endpoints', () async {
    final List<RequestOptions> requests = <RequestOptions>[];
    final Dio dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (RequestOptions options, handler) {
            requests.add(options);
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'email': 'customer@example.com',
                  'next': 'password',
                },
              ),
            );
          },
        ),
      );
    final DioAuthApiTransport transport = DioAuthApiTransport(
      storeUri: Uri.parse('https://shop.example.com/store/'),
      dio: dio,
    );

    final identity = await transport.identify('customer@example.com');

    expect(identity.isRegistered, isTrue);
    expect(
      requests.single.uri.path,
      '/store/wp-json/woo-mobile/v1/auth/identify',
    );
    expect(requests.single.method, 'POST');
    expect(requests.single.data, <String, dynamic>{
      'email': 'customer@example.com',
    });
  });

  test('attaches the opaque session only to the customer profile request', () async {
    RequestOptions? captured;
    final Dio dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (RequestOptions options, handler) {
            captured = options;
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'user': <String, dynamic>{
                    'id': 7,
                    'email': 'customer@example.com',
                    'display_name': 'Customer',
                  },
                },
              ),
            );
          },
        ),
      );
    final DioAuthApiTransport transport = DioAuthApiTransport(
      storeUri: Uri.parse('https://shop.example.com'),
      dio: dio,
    );

    final String token = 'kma1.7.${List<String>.filled(64, 'b').join()}';
    await transport.currentUser(token);

    expect(captured?.method, 'GET');
    expect(captured?.headers['X-Kidia-Session'], token);
  });
}
