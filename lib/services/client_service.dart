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