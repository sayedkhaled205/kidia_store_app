final class ForegroundPushNotice {
  ForegroundPushNotice({
    required this.title,
    required this.body,
    required Map<String, dynamic> data,
  }) : data = Map<String, dynamic>.unmodifiable(data);
  final String title;
  final String body;
  final Map<String, dynamic> data;
}
