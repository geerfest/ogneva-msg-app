class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.displayName,
    this.email,
    this.phone,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      role: json['role'] as String,
      displayName: json['display_name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }

  final String id;
  final String role;
  final String displayName;
  final String? email;
  final String? phone;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'display_name': displayName,
      'email': email,
      'phone': phone,
    };
  }
}
