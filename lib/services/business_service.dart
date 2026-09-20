import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> createBusinessProfile({required String businessName}) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    await _client.from('businesses').insert({
      'id': user.id,
      'name': businessName.trim(),
      'email': user.email,
      'plan': 'free',
    });
  }

  Future<Map<String, dynamic>?> getBusinessProfile() async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    return _client.from('businesses').select().eq('id', user.id).maybeSingle();
  }
}