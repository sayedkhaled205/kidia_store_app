class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName = '',
    this.firstName = '',
    this.lastName = '',
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final int id = switch (json['id']) {
      final int value => value,
      final Object value => int.tryParse(value.toString()) ?? 0,
      null => 0,
    };
    final String email = json['email']?.toString().trim() ?? '';
    if (id <= 0 ||
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      throw const FormatException('The authentication user is invalid.');
    }

    return AuthUser(
      id: id,
      email: email,
      displayName: json['display_name']?.toString().trim() ?? '',
      firstName: json['first_name']?.toString().trim() ?? '',
      lastName: json['last_name']?.toString().trim() ?? '',
    );
  }

  final int id;
  final String email;
  final String displayName;
  final String firstName;
  final String lastName;

  String get name {
    final String fullName = <String>[
      firstName.trim(),
      lastName.trim(),
    ].where((String part) => part.isNotEmpty).join(' ');
    if (fullName.isNotEmpty) {
      return fullName;
    }
    if (displayName.trim().isNotEmpty) {
      return displayName.trim();
    }
    return email;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'email': email,
    'display_name': displayName,
    'first_name': firstName,
    'last_name': lastName,
  };
}
