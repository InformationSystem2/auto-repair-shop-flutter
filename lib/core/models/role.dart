class Role {
  final int id;
  final String name;
  final String? description;

  Role({required this.id, required this.name, this.description});

  factory Role.fromJson(Map<String, dynamic> json) => Role(
        id: json['id'] as int,
        name: json['name'] as String,
        description: json['description'] as String?,
      );

  String get displayName {
    switch (name) {
      case 'admin':
        return 'Administrador';
      case 'client':
        return 'Cliente';
      case 'workshop_owner':
        return 'Dueño de Taller';
      case 'technician':
        return 'Técnico';
      default:
        return name;
    }
  }
}
