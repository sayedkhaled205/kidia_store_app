import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobishop_store_app/features/auth/data/website_auth_service.dart';
import 'package:mobishop_store_app/features/auth/data/storage/auth_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final id = 'a' * 64;
  final code = '$id.${'b' * 64}';
  late Dio dio;
  late MemoryAuthSessionStore storage;
  late List<RequestOptions> requests;
  late String state;
  late String challenge;
  String? authorizeOverride;
  int exchangeStatus = 200;
  int configStatus = 200;
  var expired = false;

  setUp(() {
    storage = MemoryAuthSessionStore();
    requests = [];
    authorizeOverride = null;
    exchangeStatus = configStatus = 200;
    expired = false;
    dio = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            requests.add(r);
            Object data;
            var status = 200;
            if (r.path.endsWith('/config')) {
              status = configStatus;
              data = {'enabled': true, 'version': 1};
            } else if (r.path.endsWith('/start')) {
              state = r.data['state'] as String;
              challenge = r.data['challenge'] as String;
              expect(r.data.containsKey('verifier'), isFalse);
              data = {
                'authorize_url':
                    authorizeOverride ??
                    'https://store.example/?mobishop_login=$id',
              };
            } else {
              expect(r.data['state'], state);
              expect(r.data['code'], code);
              expect(
                sha256
                    .convert(utf8.encode(r.data['verifier'] as String))
                    .toString(),
                challenge,
              );
              status = exchangeStatus;
              data = {
                'token': 'test-session',
                'expires_at': DateTime.now()
                    .add(Duration(days: expired ? -1 : 1))
                    .toIso8601String(),
                'user': {
                  'id': 27,
                  'email': 'chosen@example.com',
                  'display_name': 'Chosen account',
                },
              };
            }
            h.resolve(
              Response(requestOptions: r, statusCode: status, data: data),
            );
          },
        ),
      );
  });

  WebsiteAuthService service(WebsiteAuthBrowser browser) => WebsiteAuthService(
    store: Uri.parse('https://store.example'),
    dio: dio,
    sessions: storage,
    browser: browser,
  );
  String callback() =>
      '${WebsiteAuthService.schemeFor(Uri.parse('https://store.example'))}://auth/complete?code=$code&state=$state';

  test(
    'stores the chosen verified customer, code exchange stays on store HTTPS',
    () async {
      final auth = service((_) async => callback());
      expect(await auth.enabled(), isTrue);
      final session = await auth.signIn();
      expect(session.user.id, 27);
      expect(storage.value, session);
      for (final r in requests) {
        expect(r.uri.origin, 'https://store.example');
        expect(r.followRedirects, isFalse);
        expect(r.uri.query, isEmpty);
      }
    },
  );
  test(
    'old connector 404 falls back; a server failure does not hide enabled flow',
    () async {
      final auth = service((_) async => callback());
      configStatus = 404;
      expect(await auth.enabled(), isFalse);
      configStatus = 503;
      await expectLater(auth.enabled(), throwsFormatException);
    },
  );
  for (final uri in [
    'https://other.example/?mobishop_login=$id',
    'http://store.example/?mobishop_login=$id',
    'https://user@store.example/?mobishop_login=$id',
  ]) {
    test('rejects unsafe authorization origin: $uri', () async {
      authorizeOverride = uri;
      await expectLater(
        service((_) async => fail('Must not launch')).signIn(),
        throwsFormatException,
      );
      expect(storage.value, isNull);
    });
  }
  for (final mutation in [
    'state',
    'scheme',
    'host',
    'duplicate',
    'duplicate-code',
    'path',
    'port',
    'credentials',
    'fragment',
  ]) {
    test(
      'rejects $mutation callback without exchanging or storing a session',
      () async {
        final auth = service(
          (_) async => switch (mutation) {
            'state' => callback().replaceFirst(state, 'c' * 64),
            'scheme' => callback().replaceFirst(
              WebsiteAuthService.schemeFor(Uri.parse('https://store.example')),
              'https',
            ),
            'host' => callback().replaceFirst('//auth/', '//other/'),
            'duplicate' => '${callback()}&state=$state',
            'duplicate-code' => '${callback()}&code=$code',
            'path' => callback().replaceFirst('/complete?', '/other?'),
            'port' => callback().replaceFirst('//auth/', '//auth:443/'),
            'credentials' => callback().replaceFirst('//auth/', '//user@auth/'),
            _ => '${callback()}#extra',
          },
        );
        await expectLater(auth.signIn(), throwsFormatException);
        expect(requests.length, 1);
        expect(storage.value, isNull);
      },
    );
  }
  test(
    'cancel clears busy state and allows a new independent attempt',
    () async {
      var attempts = 0;
      final auth = service((_) async {
        if (++attempts == 1) throw PlatformException(code: 'CANCELED');
        return callback();
      });
      await expectLater(auth.signIn(), throwsA(isA<PlatformException>()));
      final firstState = state;
      expect(storage.value, isNull);
      await auth.signIn();
      expect(state, isNot(firstState));
      expect(storage.value?.user.id, 27);
    },
  );
  test('rejected or expired exchange never publishes a session', () async {
    final auth = service((_) async => callback());
    exchangeStatus = 401;
    await expectLater(auth.signIn(), throwsFormatException);
    exchangeStatus = 200;
    expired = true;
    await expectLater(auth.signIn(), throwsFormatException);
    expect(storage.value, isNull);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform native browser adapter uses store callback and exchanges selected account',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        final calls = <MethodCall>[];
        const channel = MethodChannel('flutter_web_auth_2');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'authenticate') return callback();
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(channel, null);
          debugDefaultTargetPlatformOverride = null;
        });
        final auth = WebsiteAuthService(
          store: Uri.parse('https://store.example'),
          dio: dio,
          sessions: storage,
        );
        final result = await auth.signIn();
        final call = calls.singleWhere((call) => call.method == 'authenticate');
        final args = Map<String, dynamic>.from(call.arguments as Map);
        expect(
          Uri.parse(args['url'] as String).origin,
          'https://store.example',
        );
        expect(
          args['callbackUrlScheme'],
          WebsiteAuthService.schemeFor(Uri.parse('https://store.example')),
        );
        expect((args['options'] as Map)['useWebview'], isFalse);
        expect(result.user.id, 27);
        expect(storage.value?.user.id, 27);
      },
    );
  }
}
