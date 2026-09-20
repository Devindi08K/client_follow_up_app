import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client.dart';

class ClientService {
  final SupabaseClient _client = Supabase.instance.client;

  Stream<List<ClientModel>> streamClients() {
    final uid = _client.auth.currentUser!.id;

    return _client
        .from('clients')
        .stream(primaryKey: ['id'])
        .eq('business_id', uid)
        .order('name')
        .map((rows) =>
        rows.map((row) => ClientModel.fromMap(row['id'] as String, row)).toList());
  }

  Future<ClientModel> createClient({
    required String name,
    required String email,
  }) async {
    final uid = _client.auth.currentUser!.id;

    final row = await _client
        .from('clients')
        .insert({
      'business_id': uid,
      'name': name.trim(),
      'email': email.trim(),
    })
        .select()
        .single();

    return ClientModel.fromMap(row['id'] as String, row);
  }
}