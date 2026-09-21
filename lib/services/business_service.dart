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

  Future<void> updateBusinessProfile({
    required String name,
    String? phone,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    await _client.from('businesses').update({
      'name': name.trim(),
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
  }

  Future<void> updateDefaultReminderCadence(List<int> cadence) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    await _client.from('businesses').update({
      'default_reminder_cadence': cadence,
    }).eq('id', user.id);
  }

}