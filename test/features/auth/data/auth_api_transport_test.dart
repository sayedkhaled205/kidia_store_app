import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kidia_store_app/features/auth/data/network/auth_api_transport.dart';
import 'package:kidia_store_app/features/auth/domain/entities/social_auth.dart';
import 'package:kidia_store_app/features/auth/domain/repositories/auth_repository.dart';

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

  test('starts social login only with a same-origin website URL', () async {
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
                  'authorize_url':
                      'https://shop.example.com/wp-login.php?loginSocial=google',
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

    final Uri uri = await transport.beginSocialSignIn(
      provider: SocialAuthProvider.google,
      state: List<String>.filled(64, 's').join(),
      verifier: List<String>.filled(64, 'v').join(),
    );

    expect(uri.host, 'shop.example.com');
    expect(captured?.uri.path, '/wp-json/woo-mobile/v1/auth/social/start');
    expect(captured?.data, containsPair('provider', 'google'));
  });

  test('rejects a social provider URL on another origin', () async {
    final Dio dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (RequestOptions options, handler) {
            handler.resolve(
              Response<dynamic>(
                requestOptions: options,
                statusCode: 200,
                data: <String, dynamic>{
                  'authorize_url': 'https://attacker.example/social',
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

    await expectLater(
      transport.beginSocialSignIn(
        provider: SocialAuthProvider.facebook,
        state: List<String>.filled(64, 's').join(),
        verifier: List<String>.filled(64, 'v').join(),
      ),
      throwsA(
        isA<AuthApiException>().having(
          (AuthApiException error) => error.kind,
          'kind',
          AuthFailureKind.invalidResponse,
        ),
      ),
    );
  });
}
