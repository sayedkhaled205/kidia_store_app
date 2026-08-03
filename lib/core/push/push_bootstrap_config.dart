final class PushBootstrapConfig {
  const PushBootstrapConfig({
    required this.enabled,
    required this.clientReady,
    required this.registrationUrl,
    required this.eventsUrl,
    required this.firebase,
  });

  factory PushBootstrapConfig.fromJson(Map<String, dynamic> json) {
    final Object? rawOptions = json['firebaseOptions'];
    return PushBootstrapConfig(
      enabled: json['enabled'] == true,
      clientReady: json['clientReady'] == true,
      registrationUrl: _httpsUrl(json['registrationUrl']),
      eventsUrl: _httpsUrl(json['eventsUrl']),
      firebase: rawOptions is Map<String, dynamic>
          ? FirebaseClientOptions.fromJson(rawOptions)
          : null,
    );
  }

  final bool enabled;
  final bool clientReady;
  final Uri? registrationUrl;
  final Uri? eventsUrl;
  final FirebaseClientOptions? firebase;

  bool get canRegister =>
      enabled && clientReady && registrationUrl != null && firebase != null;

  static Uri? _httpsUrl(Object? value) {
    final Uri? uri = Uri.tryParse(value is String ? value.trim() : '');
    return uri != null && uri.scheme == 'https' && uri.hasAuthority ? uri : null;
  }
}

final class FirebaseClientOptions {
  const FirebaseClientOptions({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    this.storageBucket,
  });

  factory FirebaseClientOptions.fromJson(Map<String, dynamic> json) {
    final FirebaseClientOptions options = FirebaseClientOptions(
      apiKey: _text(json['apiKey']),
      appId: _text(json['appId']),
      messagingSenderId: _text(json['messagingSenderId']),
      projectId: _text(json['projectId']),
      storageBucket: _nullableText(json['storageBucket']),
    );
    return options.isComplete ? options : const FirebaseClientOptions.empty();
  }

  const FirebaseClientOptions.empty()
      : apiKey = '',
        appId = '',
        messagingSenderId = '',
        projectId = '',
        storageBucket = null;

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String? storageBucket;

  bool get isComplete =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty;

  static String _text(Object? value) => value is String ? value.trim() : '';

  static String? _nullableText(Object? value) {
    final String text = _text(value);
    return text.isEmpty ? null : text;
  }
}
