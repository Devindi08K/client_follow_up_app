import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles account-deletion requests and data export
/// (GLOBAL_READINESS §1.AB / §2 Phase G5 — privacy controls).
class AccountService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> requestAccountDeletion() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    await _client.from('deletion_requests').insert({
      'business_id': user.id,
      'email': user.email,
    });
  }

  /// Returns a plain-text summary of everything stored about this business
  /// — clients, requests, and items, but never message contents or
  /// documents, since those were never stored in the first place
  /// (PRODUCT_SPECIFICATION §16).
  Future<String> exportDataAsText() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    final business = await _client.from('businesses').select().eq('id', user.id).maybeSingle();
    final clients = await _client.from('clients').select().eq('business_id', user.id);
    final requests = await _client
        .from('requests')
        .select('*, request_items(*)')
        .eq('business_id', user.id);

    final buffer = StringBuffer();
    buffer.writeln('CLIENT FOLLOW-UP — DATA EXPORT');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln();
    buffer.writeln('BUSINESS');
    buffer.writeln('Name: ${business?['name'] ?? ''}');
    buffer.writeln('Email: ${business?['email'] ?? ''}');
    buffer.writeln('Phone: ${business?['phone'] ?? ''}');
    buffer.writeln();
    buffer.writeln('CLIENTS (${clients.length})');
    for (final c in clients) {
      buffer.writeln('- ${c['name']} | ${c['email'] ?? ''} | ${c['phone'] ?? ''}');
    }
    buffer.writeln();
    buffer.writeln('REQUESTS (${requests.length})');
    for (final r in requests) {
      buffer.writeln('- ${r['title']} [${r['status']}]');
      final items = (r['request_items'] as List?) ?? [];
      for (final i in items) {
        buffer.writeln('    • ${i['name']}: ${i['status']}');
      }
    }

    return buffer.toString();
  }
}