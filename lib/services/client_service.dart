import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client.dart';

class ClientService {
  final SupabaseClient _client = Supabase.instance.client;

  Stream<List<ClientModel>> streamClients() {
    final user = _client.auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return _client
        .from('clients')
        .stream(primaryKey: ['id'])
        .eq('business_id', user.id)
        .order('name')
        .map(
          (rows) => rows
          .map(
            (row) => ClientModel.fromMap(
          row['id'] as String,
          row,
        ),
      )
          .toList(),
    );
  }

  Future<ClientModel> createClient({
    required String name,
    required String email,
    String? phone,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final row = await _client
        .from('clients')
        .insert({
      'business_id': user.id,
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone?.trim().isEmpty == true
          ? null
          : phone?.trim(),
    })
        .select()
        .single();

    return ClientModel.fromMap(
      row['id'] as String,
      row,
    );
  }

  /// Edits a client's contact details (CLIENT MANAGEMENT §2 — Edit client).
  Future<ClientModel> updateClient({
    required String id,
    required String name,
    required String email,
    String? phone,
  }) async {
    final row = await _client
        .from('clients')
        .update({
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', id)
        .select()
        .single();

    return ClientModel.fromMap(row['id'] as String, row);
  }

  /// Deletes a client (CLIENT MANAGEMENT §3). If the client still has
  /// requests attached, the FK constraint on requests.client_id will reject
  /// this — surface that as a friendly message instead of a raw DB error.
  Future<void> deleteClient(String id) async {
    try {
      await _client.from('clients').delete().eq('id', id);
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('foreign key') || message.contains('violates')) {
        throw Exception(
            "This client still has requests attached. Cancel or complete them first, then delete the client.");
      }
      rethrow;
    }
  }

  Future<int> countClients() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final rows = await _client
        .from('clients')
        .select('id')
        .eq('business_id', user.id);

    return rows.length;
  }
}