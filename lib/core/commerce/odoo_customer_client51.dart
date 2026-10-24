import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'commerce_connection.dart';
import 'odoo_customer_session_store51.dart';

/// A direct Odoo portal-customer client. This deliberately does not implement
/// Woo's bearer-token repositories or registration. Native cart operations
/// require the separately negotiated, website-bound Odoo 85.1 contract.
/// Its separate Odoo providers are not a replacement for Woo's UI/auth graph.
/// HTTP and Native acceptance are still required before activating those routes.
class OdooCustomerClient51 {
  OdooCustomerClient51({
    required CommerceConnection connection,
    HttpClientAdapter? adapter,
    OdooCustomerSessionStore51? sessionStore,
  }) : origin = connection.storeOrigin,
       _sessionStore = sessionStore ?? MemoryOdooCustomerSessionStore51(),
       _dio = Dio(
         BaseOptions(
           connectTimeout: const Duration(seconds: 10),
           sendTimeout: const Duration(seconds: 10),
           receiveTimeout: const Duration(seconds: 20),
           followRedirects: false,
           maxRedirects: 0,
           validateStatus: (status) => status != null,
           responseType: ResponseType.json,
         ),
       ) {
    if (connection.platform != CommercePlatform.odoo) {
      throw const FormatException('An Odoo customer connection is required.');
    }
    if (adapter != null) _dio.httpClientAdapter = adapter;
  }

  static const _prefix = '/api/mobile/v1/customer';
  final Uri origin;
  final Dio _dio;
  final OdooCustomerSessionStore51 _sessionStore;
  Future<void> _storageTail = Future<void>.value();
  Future<void>? _loadingStore;
  bool _storeLoaded = false;
  int _storageGeneration = 0;
  ({int customerId, int partnerId})? _expectedIdentity;
  _OdooCookie51? _cookie;
  String? _csrf;
  OdooCustomerProfile51? _customer;
  int _generation = 0;
  bool _writing = false;
  bool _closed = false;
  bool _identityVerified = false;
  _OdooLogoutSnapshot51? _verifiedLogout;
  Future<void>? _logoutFuture;
  Future<OdooCustomerSession51>? _publicSessionRead51;
  ({int generation, String? sid, int? customerId, int? partnerId})?
  _publicSessionReadKey51;
  Future<void>? _cartBootstrap85;
  bool _cartEnabled85 = false;
  bool _checkoutEnabled85 = false;
  bool _freeCheckout85 = false;
  bool _paymentHandoff85 = false;
  int _ownerEpoch85 = 0;

  /// Local revocation stamp only. Never sent as a credential or persisted.
  int get sessionEpoch85 => _ownerEpoch85;
  bool get cartSupported85 =>
      !_closed &&
      _cartEnabled85 &&
      _cookie != null &&
      _cookie!.expiresAt.isAfter(DateTime.now().toUtc());
  bool get checkoutSupported85 => cartSupported85 && _checkoutEnabled85;
  bool get freeCheckoutSupported85 => checkoutSupported85 && _freeCheckout85;
  bool get paymentHandoffSupported85 =>
      checkoutSupported85 && _paymentHandoff85;

  bool get isAuthenticated =>
      !_closed &&
      _identityVerified &&
      _customer != null &&
      _cookie != null &&
      _cookie!.expiresAt.isAfter(DateTime.now().toUtc());
  OdooCustomerProfile51? get customer => isAuthenticated ? _customer : null;
  DateTime? get sessionExpiresAt => isAuthenticated ? _cookie!.expiresAt : null;

  /// Same-owner view used by the Native notifier. Rolling, verified cookie
  /// expiry never replaces the logical UI identity or remounts a dirty form.
  OdooCustomerSession51 get verifiedSession51 => _boundSession51(customer);

  OdooCustomerSession51 _boundSession51(OdooCustomerProfile51? profile) {
    if (profile == null) return const OdooCustomerSession51();
    final epoch = sessionEpoch85;
    return OdooCustomerSession51(
      customer: profile,
      expiresAt: sessionExpiresAt,
      verifiedExpiry51: () {
        final current = customer;
        if (epoch != sessionEpoch85 ||
            current?.id != profile.id ||
            current?.partnerId != profile.partnerId) {
          return null;
        }
        return sessionExpiresAt;
      },
    );
  }

  /// A fresh server read, not permission to use a cached customer while offline.
  /// Odoo enforces website/company ownership in its session claim on every route;
  /// those IDs are not present in contract 51.1's public response.
  Future<OdooCustomerSession51> session() async {
    if (_logoutFuture != null) {
      throw const OdooCustomerException51('customer_session_changed');
    }
    await _loadStoredSession();
    if (_logoutFuture != null) {
      throw const OdooCustomerException51('customer_session_changed');
    }
    final expected = _expectedIdentity;
    final key = (
      generation: _generation,
      sid: _cookie?.value,
      customerId: expected?.customerId ?? _customer?.id,
      partnerId: expected?.partnerId ?? _customer?.partnerId,
    );
    final existing = _publicSessionRead51;
    if (existing != null && _publicSessionReadKey51 == key) return existing;
    late final Future<OdooCustomerSession51> read;
    // Foreground revalidation and the initial cart share one same-owner read.
    // A new SID/generation or expected UID never joins an older verification.
    // Internal login/private-SID verification calls _session directly, so it
    // cannot await its own public read or weaken its exact identity check.
    read = _session().whenComplete(() {
      if (identical(_publicSessionRead51, read)) {
        _publicSessionRead51 = null;
        _publicSessionReadKey51 = null;
      }
    });
    _publicSessionRead51 = read;
    _publicSessionReadKey51 = key;
    return read;
  }

  /// A stored SID is only a candidate. No cached identity is exposed offline.
  Future<OdooCustomerSession51> restoreSession() => _write(() async {
    await _loadStoredSession();
    if (_cookie == null) return const OdooCustomerSession51();
    return _session();
  });

  Future<T> _storeOperation<T>(Future<T> Function() operation) {
    final result = _storageTail.then((_) => operation());
    _storageTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> _loadStoredSession() {
    if (_storeLoaded) return Future<void>.value();
    return _loadingStore ??= _readStoredSession().whenComplete(
      () => _loadingStore = null,
    );
  }

  Future<void> _readStoredSession() async {
    final ticket = _generation;
    OdooCustomerStoredSession51? stored;
    try {
      stored = await _storeOperation(_sessionStore.read);
    } on FormatException {
      _assertCurrent(ticket);
      await clearLocalSession();
      _storeLoaded = true;
      return;
    } catch (_) {
      _assertCurrent(ticket);
      throw const OdooCustomerException51('customer_session_storage_failed');
    }
    _assertCurrent(ticket);
    if (stored != null && (stored.origin != origin || stored.isExpired)) {
      await clearLocalSession();
      _storeLoaded = true;
      return;
    }
    _storeLoaded = true;
    if (stored != null) {
      _cookie = _OdooCookie51(stored.sessionId, stored.expiresAt);
      _expectedIdentity = stored.isGuest
          ? null
          : (customerId: stored.customerId, partnerId: stored.partnerId);
      _csrf = null;
      _customer = null;
      _identityVerified = false;
    }
  }

  Future<void> _persistSession(OdooCustomerProfile51? customer) async {
    final ticket = _generation;
    final storageTicket = _storageGeneration;
    final cookie = _cookie!;
    final stored = OdooCustomerStoredSession51(
      origin: origin,
      sessionId: cookie.value,
      expiresAt: cookie.expiresAt,
      customerId: customer?.id ?? 0,
      partnerId: customer?.partnerId ?? 0,
    );
    try {
      await _storeOperation(() async {
        if (_closed ||
            ticket != _generation ||
            storageTicket != _storageGeneration) {
          return;
        }
        await _sessionStore.write(stored);
        if (storageTicket != _storageGeneration) {
          await _sessionStore.clearIf(stored);
        }
      });
    } catch (_) {
      if (!_closed && ticket == _generation) {
        try {
          await clearLocalSession();
        } catch (_) {
          /* Remain locally revoked. */
        }
      }
      throw const OdooCustomerException51('customer_session_storage_failed');
    }
    _assertCurrent(ticket);
  }

  Future<OdooCustomerSession51> _session({
    OdooCustomerProfile51? loginCustomer,
  }) async {
    final expected =
        _expectedIdentity ??
        (_customer == null && loginCustomer == null
            ? null
            : (
                customerId: (_customer ?? loginCustomer!).id,
                partnerId: (_customer ?? loginCustomer!).partnerId,
              ));
    _cartEnabled85 = false;
    _checkoutEnabled85 = false;
    _freeCheckout85 = false;
    _paymentHandoff85 = false;
    final response = await _request('session');
    final auth = _object(response['auth']);
    if (auth['protocol'] != 'odoo_session_cookie' ||
        auth['authenticated'] is! bool) {
      throw _invalid();
    }
    final csrf = _text(auth['csrf_token'], maximum: 512, required: true);
    if (csrf.contains(RegExp(r'[\s\x00-\x1f\x7f]'))) throw _invalid();
    final rawCustomer = response['customer'];
    final authenticated = auth['authenticated'] as bool;
    final next = authenticated
        ? OdooCustomerProfile51.fromJson(_object(rawCustomer))
        : null;
    if ((!authenticated && rawCustomer != null) ||
        (next != null && (_cookie == null || expected == null))) {
      throw _invalid();
    }
    if (expected != null &&
        (next == null ||
            next.id != expected.customerId ||
            next.partnerId != expected.partnerId)) {
      await clearLocalSession();
      throw const OdooCustomerException51('customer_session_changed');
    }
    final capabilities = _object(response['capabilities']);
    const expectedCapabilities = {
      'profile': true,
      'addresses': true,
      'orders': true,
      'register': false,
      'push': false,
    };
    if (expectedCapabilities.entries.any(
      (entry) =>
          capabilities[entry.key] is! bool ||
          capabilities[entry.key] != entry.value,
    )) {
      throw _invalid();
    }
    final cartEnabled = capabilities['cart'];
    final checkoutEnabled = capabilities['checkout'];
    if (cartEnabled is! bool ||
        checkoutEnabled is! bool ||
        (checkoutEnabled && !cartEnabled) ||
        ((cartEnabled || checkoutEnabled) &&
            response['cart_contract_version'] != '85.1')) {
      throw _invalid();
    }
    var verifiedFree = false, verifiedHandoff = false;
    if (cartEnabled) {
      final free = capabilities['free_checkout'];
      final handoff = capabilities['payment_handoff'];
      if (free is! bool ||
          handoff is! bool ||
          checkoutEnabled != (free || handoff)) {
        throw _invalid();
      }
      verifiedFree = free;
      verifiedHandoff = handoff;
    }
    _cartEnabled85 = cartEnabled;
    _checkoutEnabled85 = checkoutEnabled;
    _freeCheckout85 = verifiedFree;
    _paymentHandoff85 = verifiedHandoff;
    _csrf = csrf;
    _customer = next;
    _identityVerified = false;
    if (next != null) {
      // The response has now proved the exact UID/partner, CSRF and capability
      // contract. Publish these credentials for revocation before storage can
      // pause login; this does NOT admit the customer as authenticated yet.
      // An unverified rotated cookie must never replace this snapshot.
      final logoutSnapshot = _OdooLogoutSnapshot51(_cookie!, csrf);
      _verifiedLogout = logoutSnapshot;
      final verificationTicket = _generation;
      await _persistSession(next);
      // The caller's await is another scheduling boundary after the storage
      // helper's check. Logout must also win in this last promotion window.
      _assertCurrent(verificationTicket);
      _expectedIdentity = (customerId: next.id, partnerId: next.partnerId);
      _identityVerified = true;
    } else if (_cartEnabled85) {
      // A genuine anonymous Odoo cart uses the same protected SID jar. This
      // candidate never promotes an anonymous identity into an authenticated
      // customer and is discarded on explicit logout/account switch.
      _verifiedLogout = _OdooLogoutSnapshot51(_cookie!, csrf);
      await _persistSession(null);
    }
    return _boundSession51(next);
  }

  Future<OdooCustomerProfile51> login({
    required String login,
    required String password,
  }) => _write(() async {
    if (isAuthenticated) {
      throw const OdooCustomerException51('sign_out_before_sign_in');
    }
    final normalized = _text(login, maximum: 254, required: true).trim();
    if (normalized.codeUnits.any((unit) => unit < 32 || unit == 127)) {
      throw const OdooCustomerException51('invalid_credentials');
    }
    if (password.isEmpty || password.length > 4096) {
      throw const OdooCustomerException51('invalid_credentials');
    }
    await session();
    if (isAuthenticated) {
      throw const OdooCustomerException51('sign_out_before_sign_in');
    }
    final response = await _request(
      'login',
      payload: {'login': normalized, 'password': password},
    );
    final claimed = OdooCustomerProfile51.fromJson(
      _object(response['customer']),
    );
    if (response['refresh_csrf'] != true) throw _invalid();
    // Login rotates Odoo's cookie. Never reuse its pre-login CSRF token.
    _csrf = null;
    final refreshed = await _session(loginCustomer: claimed);
    final user = refreshed.customer;
    if (user == null ||
        user.id != claimed.id ||
        user.partnerId != claimed.partnerId) {
      await clearLocalSession();
      throw const OdooCustomerException51('customer_session_changed');
    }
    return user;
  });

  /// Cart operations share the exact customer session transport. The whitelist
  /// is intentionally closed; no arbitrary Odoo/admin/builder URL is admitted.
  Future<Map<String, dynamic>> cart85() => _cartRequest85('cart');

  Future<Map<String, dynamic>> addCartItem85({
    required int productId,
    required int quantity,
  }) => _write(() {
    if (quantity < 1 || quantity > 2147483647) {
      throw const OdooCustomerException51('invalid_cart_quantity');
    }
    return _cartRequest85(
      'cart/items',
      payload: {'product_id': _positiveId(productId), 'quantity': quantity},
    );
  });

  Future<Map<String, dynamic>> updateCartItem85({
    required int lineId,
    required int quantity,
  }) => _write(() {
    if (quantity < 0 || quantity > 2147483647) {
      throw const OdooCustomerException51('invalid_cart_quantity');
    }
    return _cartRequest85(
      'cart/items/${_positiveId(lineId)}',
      payload: {'quantity': quantity},
    );
  });

  Future<void> _ensureCartSession85() async {
    if (_csrf == null ||
        !_cartEnabled85 ||
        _cookie == null ||
        !_cookie!.expiresAt.isAfter(DateTime.now().toUtc())) {
      final pending = _cartBootstrap85 ??= session().then<void>((_) {});
      try {
        await pending;
      } finally {
        if (identical(_cartBootstrap85, pending)) _cartBootstrap85 = null;
      }
    }
    if (!_cartEnabled85) {
      throw const OdooCustomerException51('cart_contract_unavailable');
    }
  }

  Future<Map<String, dynamic>> _cartRequest85(
    String endpoint, {
    Map<String, dynamic>? payload,
  }) async {
    await _ensureCartSession85();
    final owner = sessionEpoch85;
    final uid = customer?.id;
    final response = await _request(endpoint, payload: payload);
    if (owner != sessionEpoch85 ||
        response['customer_id'] != uid ||
        response['cart_contract_version'] != '85.1') {
      throw const OdooCustomerException51('customer_session_changed');
    }
    return response;
  }

  Future<OdooCustomerProfile51> profile() async {
    final expected = _requireCustomer();
    final response = await _request('profile');
    return _ownProfile(response['customer'], expected);
  }

  Future<OdooCustomerProfile51> updateProfile(Map<String, String> fields) =>
      _write(() async {
        final expected = _requireCustomer();
        final patch = Map<String, String>.unmodifiable(fields);
        _profilePatch(patch);
        await _ensureCsrf();
        final response = await _request('profile', payload: patch);
        return _ownProfile(response['customer'], expected);
      });

  Future<OdooCustomerAddresses51> addresses() async {
    final expected = _requireCustomer();
    final response = await _request('addresses');
    final primary = OdooCustomerAddress51.fromJson(
      _object(response['primary']),
    );
    if (primary.id != expected.partnerId) throw _invalid();
    final items = _array(response['items']);
    if (items.length > 100) throw _invalid();
    final result = items
        .map((raw) => OdooCustomerAddress51.fromJson(_object(raw)))
        .toList(growable: false);
    final ids = <int>{primary.id};
    if (result.any(
      (address) =>
          !ids.add(address.id) ||
          !const {'invoice', 'delivery'}.contains(address.type),
    )) {
      throw _invalid();
    }
    return OdooCustomerAddresses51(primary: primary, items: result);
  }

  Future<OdooCustomerAddress51> createAddress(Map<String, dynamic> fields) =>
      _write(() async {
        _requireCustomer();
        final patch = Map<String, dynamic>.unmodifiable(fields);
        _addressPatch(patch, creating: true);
        await _ensureCsrf();
        final response = await _request('addresses', payload: patch);
        return OdooCustomerAddress51.fromJson(_object(response['address']));
      });

  Future<OdooCustomerAddress51> updateAddress(
    int id,
    Map<String, dynamic> fields,
  ) => _write(() async {
    _requireCustomer();
    _positiveId(id);
    final patch = Map<String, dynamic>.unmodifiable(fields);
    _addressPatch(patch, creating: false);
    await _ensureCsrf();
    final response = await _request('addresses/$id', payload: patch);
    final result = OdooCustomerAddress51.fromJson(_object(response['address']));
    if (result.id != id) throw _invalid();
    return result;
  });

  Future<OdooCustomerOrderPage51> orders({int page = 1}) async {
    _requireCustomer();
    if (page < 1 || page > 10000) {
      throw const OdooCustomerException51('invalid_page');
    }
    final response = await _request('orders', page: page);
    final result = OdooCustomerOrderPage51.fromJson(response);
    if (result.page != page) throw _invalid();
    return result;
  }

  Future<OdooCustomerOrder51> order(int id) async {
    _requireCustomer();
    _positiveId(id);
    final response = await _request('orders/$id');
    final result = OdooCustomerOrder51.fromJson(
      _object(response['order']),
      detail: true,
    );
    if (result.id != id) throw _invalid();
    return result;
  }

  Future<OdooCustomerRevision51> revision() async {
    final expected = _requireCustomer();
    final response = await _request('revision');
    final result = OdooCustomerRevision51.fromJson(
      _object(response['revision']),
    );
    if (result.customerId != expected.id) throw _invalid();
    return result;
  }

  Future<void> logout() {
    if (_closed) {
      return Future.error(
        const OdooCustomerException51('customer_session_required'),
      );
    }
    if (_logoutFuture != null) return _logoutFuture!;
    final snapshot = _verifiedLogout;
    final hadSession =
        snapshot != null ||
        _cookie != null ||
        _loadingStore != null ||
        _writing;
    // Invalidate old reads immediately. No late response may restore this user
    // or its cookie after logout, including while another explicit write waits.
    Object? revocationError;
    final revoked = clearLocalSession().catchError((Object error) {
      revocationError = error;
    });
    Future<void> finish() async {
      try {
        // Cold restore has no trusted CSRF/identity. During SID verification,
        // attempt server logout with the previous VERIFIED snapshot only.
        if (snapshot != null &&
            snapshot.cookie.expiresAt.isAfter(DateTime.now().toUtc())) {
          final response = await _request(
            'logout',
            payload: const {},
            overrideCookie: snapshot.cookie,
            overrideCsrf: snapshot.csrf,
            acceptCookie: false,
          );
          if (response['signed_out'] != true) throw _invalid();
        } else if (!hadSession) {
          // Repeating a completed/failed logout never replays the mutation.
          throw const OdooCustomerException51('customer_session_required');
        }
      } finally {
        await revoked;
        if (revocationError != null) throw revocationError!;
      }
    }

    late final Future<void> operation;
    operation = finish().whenComplete(() {
      if (identical(_logoutFuture, operation)) _logoutFuture = null;
    });
    _logoutFuture = operation;
    return operation;
  }

  /// Local revocation only. This never silently retries a failed mutation.
  Future<void> clearLocalSession() {
    _storageGeneration += 1;
    _clearMemory();
    return _storeOperation(_sessionStore.clear).catchError((Object _) {
      throw const OdooCustomerException51('customer_session_storage_failed');
    });
  }

  void _clearMemory() {
    _generation += 1;
    _ownerEpoch85 += 1;
    _cartEnabled85 = false;
    _checkoutEnabled85 = false;
    _freeCheckout85 = false;
    _paymentHandoff85 = false;
    _cookie = null;
    _csrf = null;
    _customer = null;
    _identityVerified = false;
    _expectedIdentity = null;
    _verifiedLogout = null;
    _publicSessionRead51 = null;
    _publicSessionReadKey51 = null;
  }

  void close() {
    _closed = true;
    _storageGeneration += 1;
    // Normal disposal keeps an already persisted, verified restore candidate.
    // A write still in flight is conditionally removed when it completes.
    _clearMemory();
    _dio.close(force: true);
  }

  OdooCustomerProfile51 _requireCustomer() {
    if (_closed ||
        !_identityVerified ||
        _customer == null ||
        _cookie == null ||
        !_cookie!.expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const OdooCustomerException51('customer_session_required');
    }
    return _customer!;
  }

  Future<T> _write<T>(Future<T> Function() action) async {
    if (_writing || _closed || _logoutFuture != null) {
      throw const OdooCustomerException51('customer_write_in_progress');
    }
    _writing = true;
    try {
      return await action();
    } finally {
      _writing = false;
    }
  }

  Future<void> _ensureCsrf() async {
    if (_csrf == null) await session();
    _requireCustomer();
  }

  OdooCustomerProfile51 _ownProfile(
    dynamic raw,
    OdooCustomerProfile51 expected,
  ) {
    final result = OdooCustomerProfile51.fromJson(_object(raw));
    if (result.id != expected.id || result.partnerId != expected.partnerId) {
      throw _invalid();
    }
    _customer = result;
    return result;
  }

  Future<Map<String, dynamic>> _request(
    String endpoint, {
    Map<String, dynamic>? payload,
    int? page,
    _OdooCookie51? overrideCookie,
    String? overrideCsrf,
    bool acceptCookie = true,
  }) async {
    if (_closed ||
        !RegExp(
          r'^(session|login|logout|profile|addresses(?:/[1-9][0-9]{0,9})?|orders(?:/[1-9][0-9]{0,9})?|revision|cart(?:/items(?:/[1-9][0-9]{0,9})?)?)$',
        ).hasMatch(endpoint)) {
      throw const OdooCustomerException51('unapproved_customer_endpoint');
    }
    if (_logoutFuture != null && endpoint != 'logout') {
      throw const OdooCustomerException51('customer_session_changed');
    }
    final ticket = _generation;
    final sentCookie = overrideCookie ?? _cookie;
    final csrf = overrideCsrf ?? _csrf;
    if (payload != null && (sentCookie == null || csrf == null)) {
      throw const OdooCustomerException51('customer_csrf_session_required');
    }
    final uri = origin
        .resolve('$_prefix/$endpoint')
        .replace(queryParameters: page == null ? null : {'page': '$page'});
    try {
      final response = await _dio.requestUri<dynamic>(
        uri,
        data: payload == null
            ? null
            : {'payload': jsonEncode(payload), 'csrf_token': csrf},
        options: Options(
          method: payload == null ? 'GET' : 'POST',
          contentType: payload == null
              ? null
              : Headers.formUrlEncodedContentType,
          headers: {
            'Accept': 'application/json',
            'Cache-Control': 'no-store, no-cache',
            'Pragma': 'no-cache',
            if (sentCookie != null) 'Cookie': 'session_id=${sentCookie.value}',
          },
        ),
      );
      _assertCurrent(ticket);
      if (response.realUri.scheme != origin.scheme ||
          response.realUri.host != origin.host ||
          response.realUri.port != origin.port ||
          response.realUri.userInfo.isNotEmpty ||
          response.realUri.path != uri.path ||
          response.statusCode == null ||
          response.statusCode! >= 300 && response.statusCode! < 400) {
        throw _invalid();
      }
      dynamic body = response.data;
      if (body is String) body = jsonDecode(body);
      final json = _object(body);
      if (json['platform'] != 'odoo' ||
          json['contract_version'] != '51.1' ||
          json['ok'] is! bool) {
        throw _invalid();
      }
      final success = response.statusCode! >= 200 && response.statusCode! < 300;
      if (json['ok'] != success) throw _invalid();
      if (!success) {
        final code = _text(
          _object(json['error'])['code'],
          maximum: 120,
          required: true,
        );
        if (response.statusCode == 401 || response.statusCode == 403) {
          await clearLocalSession();
        }
        throw OdooCustomerException51(
          code,
          statusCode: response.statusCode,
          response: json,
        );
      }
      if (acceptCookie) {
        final cookies = response.headers['set-cookie'] ?? const <String>[];
        final sessionCookies = cookies
            .where((raw) => raw.split('=').first.trim() == 'session_id')
            .toList(growable: false);
        if (sessionCookies.length != 1) throw _invalid();
        final next = _OdooCookie51.parse(sessionCookies.single);
        // Cookie rotation invalidates other requests that used an older SID.
        final rotated = sentCookie?.value != next.value;
        final hadCartContract = _cartEnabled85;
        if (rotated) {
          _generation += 1;
          _csrf = null;
          _identityVerified = false;
          _cartEnabled85 = false;
          _checkoutEnabled85 = false;
          _freeCheckout85 = false;
          _paymentHandoff85 = false;
        }
        _cookie = next;
        if (rotated &&
            (_customer != null || hadCartContract) &&
            !const {'session', 'login', 'logout'}.contains(endpoint)) {
          // A private response must never install a different customer's SID
          // for the next orders/address read. Re-prove the exact uid/partner
          // with the rotated cookie before exposing this response at all.
          final verificationTicket = _generation;
          try {
            await _session();
            _assertCurrent(verificationTicket);
          } catch (_) {
            if (_generation == verificationTicket) await clearLocalSession();
            rethrow;
          }
        }
      }
      return json;
    } on OdooCustomerException51 {
      rethrow;
    } on DioException catch (error) {
      _assertCurrent(ticket);
      throw OdooCustomerException51(switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.transformTimeout => 'customer_request_timeout',
        DioExceptionType.badCertificate => 'customer_certificate_invalid',
        DioExceptionType.cancel => 'customer_request_cancelled',
        _ => 'customer_connection_failed',
      });
    } on FormatException {
      throw _invalid();
    }
  }

  void _assertCurrent(int ticket) {
    if (_closed || ticket != _generation) {
      throw const OdooCustomerException51('customer_session_changed');
    }
  }
}

class _OdooLogoutSnapshot51 {
  const _OdooLogoutSnapshot51(this.cookie, this.csrf);
  final _OdooCookie51 cookie;
  final String csrf;
}

class OdooCustomerException51 implements Exception {
  const OdooCustomerException51(this.code, {this.statusCode, this.response});
  final String code;
  final int? statusCode;

  /// A validated public envelope, never the request/cookie/CSRF credentials.
  final Map<String, dynamic>? response;
  @override
  String toString() => 'Odoo customer request failed ($code).';
}

class OdooCustomerSession51 {
  const OdooCustomerSession51({
    OdooCustomerProfile51? customer,
    DateTime? expiresAt,
    DateTime? Function()? verifiedExpiry51,
  })
    // Keep the public constructor name while hiding an expired identity.
    // ignore: prefer_initializing_formals
    : _customer = customer,
       // Keep the backwards-compatible public constructor field names.
       // ignore: prefer_initializing_formals
       _expiresAt = expiresAt,
       // ignore: prefer_initializing_formals
       _verifiedExpiry51 = verifiedExpiry51;
  final OdooCustomerProfile51? _customer;
  final DateTime? _expiresAt;
  final DateTime? Function()? _verifiedExpiry51;
  DateTime? get expiresAt =>
      _verifiedExpiry51 == null ? _expiresAt : _verifiedExpiry51();
  OdooCustomerProfile51? get customer => authenticated ? _customer : null;
  bool get authenticated {
    final expiry = expiresAt;
    return _customer != null &&
        expiry != null &&
        expiry.isAfter(DateTime.now().toUtc());
  }
}

class OdooCustomerProfile51 {
  const OdooCustomerProfile51({
    required this.id,
    required this.partnerId,
    required this.name,
    required this.email,
    required this.login,
    required this.phone,
    required this.mobile,
    required this.address,
  });
  factory OdooCustomerProfile51.fromJson(Map<String, dynamic> json) {
    final editable = _array(json['editable_fields']);
    if (editable.length != 3 ||
        editable.toSet().length != 3 ||
        !editable.toSet().containsAll(const {'name', 'phone', 'mobile'})) {
      throw _invalid();
    }
    final partnerId = _positiveId(json['partner_id']);
    final address = OdooCustomerAddress51.fromJson(_object(json['address']));
    if (address.id != partnerId) throw _invalid();
    return OdooCustomerProfile51(
      id: _positiveId(json['id']),
      partnerId: partnerId,
      name: _text(json['name']),
      email: _text(json['email'], maximum: 254),
      login: _text(json['login'], maximum: 254, required: true),
      phone: _text(json['phone'], maximum: 120),
      mobile: _text(json['mobile'], maximum: 120),
      address: address,
    );
  }
  final int id;
  final int partnerId;
  final String name, email, login, phone, mobile;
  final OdooCustomerAddress51 address;
}

class OdooCustomerAddress51 {
  OdooCustomerAddress51._({
    required this.id,
    required this.type,
    required this.values,
    required this.countryId,
    required this.stateId,
  });
  factory OdooCustomerAddress51.fromJson(Map<String, dynamic> json) {
    final type = _text(json['type']);
    if (!const {
      'contact',
      'invoice',
      'delivery',
      'other',
      'private',
    }.contains(type)) {
      throw _invalid();
    }
    return OdooCustomerAddress51._(
      id: _positiveId(json['id']),
      type: type,
      values: Map<String, String>.unmodifiable({
        for (final key in const [
          'name',
          'phone',
          'mobile',
          'street',
          'street2',
          'city',
          'zip',
          'country_code',
          'state_name',
        ])
          key: _text(
            json[key],
            maximum: key == 'phone' || key == 'mobile' ? 120 : 240,
          ),
      }),
      countryId: json['country_id'] == null
          ? null
          : _positiveId(json['country_id']),
      stateId: json['state_id'] == null ? null : _positiveId(json['state_id']),
    );
  }
  final int id;
  final String type;
  final Map<String, String> values;
  final int? countryId, stateId;
}

class OdooCustomerAddresses51 {
  OdooCustomerAddresses51({
    required this.primary,
    required List<OdooCustomerAddress51> items,
  }) : items = List<OdooCustomerAddress51>.unmodifiable(items);
  final OdooCustomerAddress51 primary;
  final List<OdooCustomerAddress51> items;
}

class OdooCustomerOrder51 {
  OdooCustomerOrder51._({
    required this.id,
    required this.name,
    required this.state,
    required this.currency,
    required this.minorUnit,
    required this.totalMinor,
    required this.taxMinor,
    required this.untaxedMinor,
    required this.date,
    required this.items,
  });
  factory OdooCustomerOrder51.fromJson(
    Map<String, dynamic> json, {
    bool detail = false,
  }) {
    final state = _text(json['state']);
    final currency = _text(json['currency']);
    final digits = json['currency_minor_unit'];
    if (!const {'sale', 'done', 'cancel'}.contains(state) ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(currency) ||
        digits is! int ||
        digits < 0 ||
        digits > 18) {
      throw _invalid();
    }
    final rawDate = json['date'];
    final date = rawDate == null ? null : DateTime.tryParse(_text(rawDate));
    if (rawDate != null && date == null) throw _invalid();
    final items = detail
        ? _array(json['items'])
              .map((raw) => OdooCustomerOrderItem51.fromJson(_object(raw)))
              .toList(growable: false)
        : <OdooCustomerOrderItem51>[];
    return OdooCustomerOrder51._(
      id: _positiveId(json['id']),
      name: _text(json['name'], required: true),
      state: state,
      currency: currency,
      minorUnit: digits,
      totalMinor: _integerText(json['total_minor']),
      taxMinor: _integerText(json['tax_minor']),
      untaxedMinor: _integerText(json['untaxed_minor']),
      date: date,
      items: List<OdooCustomerOrderItem51>.unmodifiable(items),
    );
  }
  final int id, minorUnit;
  final String name, state, currency, totalMinor, taxMinor, untaxedMinor;
  final DateTime? date;
  final List<OdooCustomerOrderItem51> items;
}

class OdooCustomerOrderItem51 {
  const OdooCustomerOrderItem51._({
    required this.id,
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPriceMinor,
    required this.subtotalMinor,
    required this.totalMinor,
  });
  factory OdooCustomerOrderItem51.fromJson(Map<String, dynamic> json) {
    final quantity = _text(json['quantity'], maximum: 80, required: true);
    if (!RegExp(
      r'^-?(0|[1-9][0-9]*)(\.[0-9]+)?(e[+-]?[0-9]{1,3})?$',
    ).hasMatch(quantity)) {
      throw _invalid();
    }
    return OdooCustomerOrderItem51._(
      id: _positiveId(json['id']),
      productId: json['product_id'] == null
          ? null
          : _positiveId(json['product_id']),
      name: _text(json['name'], maximum: 16000, required: true),
      quantity: quantity,
      unitPriceMinor: _integerText(json['unit_price_minor']),
      subtotalMinor: _integerText(json['subtotal_minor']),
      totalMinor: _integerText(json['total_minor']),
    );
  }
  final int id;
  final int? productId;
  final String name, quantity, unitPriceMinor, subtotalMinor, totalMinor;
}

class OdooCustomerOrderPage51 {
  OdooCustomerOrderPage51._({
    required this.items,
    required this.page,
    required this.total,
  });
  factory OdooCustomerOrderPage51.fromJson(Map<String, dynamic> json) {
    final page = _positiveId(json['page']);
    final total = json['total'];
    final rawItems = _array(json['items']);
    if (page > 10000 ||
        json['page_size'] != 20 ||
        json['page_size'] is! int ||
        total is! int ||
        total < 0 ||
        rawItems.length > 20 ||
        rawItems.length > total) {
      throw _invalid();
    }
    final items = rawItems
        .map((raw) => OdooCustomerOrder51.fromJson(_object(raw)))
        .toList(growable: false);
    if (items.map((item) => item.id).toSet().length != items.length) {
      throw _invalid();
    }
    return OdooCustomerOrderPage51._(
      items: List<OdooCustomerOrder51>.unmodifiable(items),
      page: page,
      total: total,
    );
  }
  final List<OdooCustomerOrder51> items;
  final int page, total;
  int get totalPages => (total / 20).ceil();
}

class OdooCustomerRevision51 {
  const OdooCustomerRevision51._({
    required this.customerId,
    required this.profile,
    required this.addresses,
    required this.orders,
  });
  factory OdooCustomerRevision51.fromJson(Map<String, dynamic> json) {
    if (json['delivery'] != 'read_after_resume_or_foreground_poll') {
      throw _invalid();
    }
    String digest(String key) {
      final value = _text(json[key], maximum: 64, required: true);
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) throw _invalid();
      return value;
    }

    return OdooCustomerRevision51._(
      customerId: _positiveId(json['customer_id']),
      profile: digest('profile'),
      addresses: digest('addresses'),
      orders: digest('orders'),
    );
  }
  final int customerId;
  final String profile, addresses, orders;
}

class _OdooCookie51 {
  const _OdooCookie51(this.value, this.expiresAt);
  factory _OdooCookie51.parse(String raw) {
    final pieces = raw.split(';').map((part) => part.trim()).toList();
    if (pieces.isEmpty || !pieces.first.startsWith('session_id=')) {
      throw _invalid();
    }
    final value = pieces.first.substring('session_id='.length);
    if (!RegExp(r'^[A-Za-z0-9_-]{16,512}$').hasMatch(value)) throw _invalid();
    final attributes = <String, String?>{};
    for (final piece in pieces.skip(1)) {
      final separator = piece.indexOf('=');
      final key = (separator < 0 ? piece : piece.substring(0, separator))
          .toLowerCase();
      if (attributes.containsKey(key)) throw _invalid();
      attributes[key] = separator < 0 ? null : piece.substring(separator + 1);
    }
    final ageText = attributes['max-age'];
    final age = ageText == null ? null : int.tryParse(ageText);
    if (!attributes.containsKey('secure') ||
        attributes['secure'] != null ||
        !attributes.containsKey('httponly') ||
        attributes['httponly'] != null ||
        attributes['samesite']?.toLowerCase() != 'strict' ||
        attributes['path'] != '/' ||
        attributes.containsKey('domain') ||
        age == null ||
        age < 1 ||
        age > 31536000) {
      throw _invalid();
    }
    return _OdooCookie51(
      value,
      DateTime.now().toUtc().add(Duration(seconds: age)),
    );
  }
  final String value;
  final DateTime expiresAt;
}

OdooCustomerException51 _invalid() =>
    const OdooCustomerException51('invalid_customer_contract');
Map<String, dynamic> _object(dynamic raw) {
  if (raw is! Map || raw.keys.any((key) => key is! String)) throw _invalid();
  return Map<String, dynamic>.from(raw);
}

List<dynamic> _array(dynamic raw) {
  if (raw is! List) throw _invalid();
  return raw;
}

int _positiveId(dynamic raw) {
  if (raw is! int || raw < 1 || raw > 9999999999) throw _invalid();
  return raw;
}

String _text(dynamic raw, {int maximum = 240, bool required = false}) {
  if (raw is! String ||
      raw.length > maximum ||
      (required && raw.trim().isEmpty) ||
      raw.codeUnits.any(
        (unit) => unit < 32 && unit != 10 && unit != 9 || unit == 127,
      )) {
    throw _invalid();
  }
  return raw;
}

String _integerText(dynamic raw) {
  if (raw is! String ||
      raw.length > 80 ||
      !RegExp(r'^(0|-?[1-9][0-9]*)$').hasMatch(raw)) {
    throw _invalid();
  }
  return raw;
}

void _profilePatch(Map<String, String> fields) {
  if (fields.isEmpty ||
      fields.keys.any(
        (key) => !const {'name', 'phone', 'mobile'}.contains(key),
      )) {
    throw _invalid();
  }
  for (final field in fields.entries) {
    _text(
      field.value,
      maximum: field.key == 'name' ? 240 : 120,
      required: field.key == 'name',
    );
  }
}

void _addressPatch(Map<String, dynamic> fields, {required bool creating}) {
  const allowed = {
    'name',
    'phone',
    'mobile',
    'street',
    'street2',
    'city',
    'zip',
    'country_id',
    'state_id',
  };
  if (fields.isEmpty ||
      fields.keys.any(
        (key) => !allowed.contains(key) && !(creating && key == 'type'),
      )) {
    throw _invalid();
  }
  if (creating &&
      (!const {'invoice', 'delivery'}.contains(fields['type']) ||
          !fields.containsKey('name'))) {
    throw _invalid();
  }
  for (final field in fields.entries) {
    if (field.key == 'type') continue;
    if (field.key == 'country_id' || field.key == 'state_id') {
      if (field.value != null && field.value != false) _positiveId(field.value);
    } else {
      _text(
        field.value,
        maximum: field.key == 'phone' || field.key == 'mobile' ? 120 : 240,
        required: field.key == 'name',
      );
    }
  }
}
