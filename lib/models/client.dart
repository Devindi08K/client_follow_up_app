// lib/models/client.dart
class ClientModel {
  final String id;
  final String name;
  final String email;

  ClientModel({required this.id, required this.name, required this.email});

  factory ClientModel.fromMap(String id, Map<String, dynamic> data) {
    return ClientModel(
      id: id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
    );
  }
}