import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Returns the existing business profile, or creates one if this is the
  /// account's first time reaching an authenticated screen (covers both the
  /// immediate-signup case and the email-confirmation-required case, where
  /// no session existed yet at signup time to safely insert under RLS).
  Future<Map<String, dynamic>> ensureBusinessProfile({String fallbackName = ''}) async {
    final existing = await getBusinessProfile();
    if (existing != null) return existing;

    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    final name = fallbackName.trim().isNotEmpty
        ? fallbackName.trim()
        : (user.email?.split('@').first ?? 'My Business');

    final row = await _client
        .from('businesses')
        .insert({
      'id': user.id,
      'name': name,
      'email': user.email,
      'plan': 'free',
    })
        .select()
        .single();

    return row;
  }

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

  Future<void> updateMessageTemplates({
    String? bodyTemplate,
    String? subjectTemplate,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    await _client.from('businesses').update({
      'message_template':
      (bodyTemplate == null || bodyTemplate.trim().isEmpty) ? null : bodyTemplate.trim(),
      'subject_template':
      (subjectTemplate == null || subjectTemplate.trim().isEmpty) ? null : subjectTemplate.trim(),
    }).eq('id', user.id);
  }

  Future<void> updateBusinessLocale({
    required String country,
    required String timezone,
    required String language,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    await _client.from('businesses').update({
      'country': country,
      'timezone': timezone,
      'language': language,
    }).eq('id', user.id);
  }

}