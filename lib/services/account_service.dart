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
  Future<String> exportClientsAsCsv() async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');
    final clients = await _client.from('clients').select().eq('business_id', user.id);

    final buffer = StringBuffer('name,email,phone,preferred_contact\n');
    for (final c in clients) {
      String esc(dynamic v) => '"${(v?.toString() ?? '').replaceAll('"', '""')}"';
      buffer.writeln('${esc(c['name'])},${esc(c['email'])},${esc(c['phone'])},${esc(c['preferred_contact'])}');
    }
    return buffer.toString();
  }

  Future<int> importClientsFromCsv(String csv) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('No authenticated user found.');

    final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) return 0;

    final existing = await _client.from('clients').select('email').eq('business_id', user.id);
    final existingEmails = existing.map((r) => (r['email'] as String? ?? '').toLowerCase()).toSet();

    var imported = 0;
    for (final line in lines.skip(1)) {
      final parts = line.split(',').map((p) => p.trim().replaceAll('"', '')).toList();
      if (parts.isEmpty || parts[0].isEmpty) continue;
      final email = parts.length > 1 ? parts[1] : '';
      if (email.isNotEmpty && existingEmails.contains(email.toLowerCase())) continue;

      await _client.from('clients').insert({
        'business_id': user.id,
        'name': parts[0],
        'email': email.isEmpty ? null : email,
        'phone': parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null,
        'preferred_contact': parts.length > 3 && parts[3].isNotEmpty ? parts[3] : 'none',
      });
      imported++;
    }
    return imported;
  }
}