import 'role.dart';

/// Refleja UserResponseDto del backend FastAPI
class User {
  final String id;
  final String username;
  final String name;
  final String lastName;
  final String email;
  final String? phone;
  final bool isActive;
  final String createdAt;
  final String updatedAt;
  final List<Role> roles;

  User({
    required this.id,
    required this.username,
    required this.name,
    required this.lastName,
    required this.email,
    this.phone,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.roles,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        username: json['username'] as String,
        name: json['name'] as String,
        lastName: json['last_name'] as String,
        email: json['email'] as String,
        phone: json['phone'] as String?,
        isActive: json['is_active'] as bool? ?? true,
        createdAt: json['created_at'] as String? ?? '',
        updatedAt: json['updated_at'] as String? ?? '',
        roles: (json['roles'] as List<dynamic>? ?? [])
            .map((r) => Role.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'name': name,
        'last_name': lastName,
        'email': email,
        'phone': phone,
        'is_active': isActive,
        'created_at': createdAt,
        'updated_at': updatedAt,
        'roles': roles.map((r) => {'id': r.id, 'name': r.name}).toList(),
      };

  String get fullName => '$name $lastName';

  String get initials {
    final first = name.isNotEmpty ? name[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$first$last';
  }

  String get primaryRole =>
      roles.isNotEmpty ? roles.first.displayName : 'Usuario';
}
