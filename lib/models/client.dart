// lib/models/client.dart
class ClientModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final DateTime? archivedAt;

  ClientModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone = '',
    this.archivedAt,
  });

  bool get isArchived => archivedAt != null;

  factory ClientModel.fromMap(String id, Map<String, dynamic> data) {
    return ClientModel(
      id: id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      archivedAt: data['archived_at'] != null
          ? DateTime.tryParse(data['archived_at'] as String)
          : null,
    );
  }
}