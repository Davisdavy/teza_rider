class UserAccount {
  final String id;
  final String email;
  final String role;
  final bool enabled;

  UserAccount({
    required this.id,
    required this.email,
    required this.role,
    required this.enabled,
  });

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      enabled: json['enabled'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'enabled': enabled,
    };
  }
}
