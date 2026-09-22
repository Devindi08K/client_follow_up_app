import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client.dart';

class ClientService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Streams this business's clients. Archived clients (GLOBAL_READINESS
  /// §1.I) are hidden by default — pass [includeArchived] to see the
  /// archived list instead. Filtering happens client-side so this stays a
  /// single simple query regardless of Supabase stream-filter support.
  Stream<List<ClientModel>> streamClients({bool includeArchived = false}) {
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
          .map((row) => ClientModel.fromMap(row['id'] as String, row))
          .where((c) => includeArchived ? c.isArchived : !c.isArchived)
          .toList(),
    );
  }

  Future<ClientModel> createClient({
    required String name,
    String? email,
    String? phone,
  }) async {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    final trimmedName = name.trim();
    final trimmedEmail = email?.trim() ?? '';
    final trimmedPhone = phone?.trim() ?? '';

    if (trimmedName.isEmpty) {
      throw Exception('Client name is required.');
    }
    if (trimmedEmail.isEmpty && trimmedPhone.isEmpty) {
      throw Exception('Add at least an email or a phone number for this client.');
    }

    final row = await _client
        .from('clients')
        .insert({
      'business_id': user.id,
      'name': trimmedName,
      'email': trimmedEmail.isEmpty ? null : trimmedEmail,
      'phone': trimmedPhone.isEmpty ? null : trimmedPhone,
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
    String? email,
    String? phone,
  }) async {
    final trimmedName = name.trim();
    final trimmedEmail = email?.trim() ?? '';
    final trimmedPhone = phone?.trim() ?? '';

    if (trimmedName.isEmpty) {
      throw Exception('Client name is required.');
    }
    if (trimmedEmail.isEmpty && trimmedPhone.isEmpty) {
      throw Exception('Add at least an email or a phone number for this client.');
    }

    final row = await _client
        .from('clients')
        .update({
      'name': trimmedName,
      'email': trimmedEmail.isEmpty ? null : trimmedEmail,
      'phone': trimmedPhone.isEmpty ? null : trimmedPhone,
      'updated_at': DateTime.now().toIso8601String(),
    })
        .eq('id', id)
        .select()
        .single();

    return ClientModel.fromMap(row['id'] as String, row);
  }

  /// Returns existing clients that look like a duplicate of the given
  /// name/email/phone (GLOBAL_READINESS §1.H — warn, never silently merge).
  /// Matches on exact (case-insensitive) email, normalized phone digits, or
  /// exact (case-insensitive) name. [excludeId] skips a client being edited.
  Future<List<ClientModel>> findPossibleDuplicates({
    required String name,
    String? email,
    String? phone,
    String? excludeId,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final trimmedName = name.trim().toLowerCase();
    final trimmedEmail = email?.trim().toLowerCase() ?? '';
    final normalizedPhone = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');

    if (trimmedName.isEmpty && trimmedEmail.isEmpty && normalizedPhone.isEmpty) {
      return [];
    }

    final rows =
    await _client.from('clients').select().eq('business_id', user.id);

    final matches = <ClientModel>[];
    for (final row in rows) {
      final id = row['id'] as String;
      if (excludeId != null && id == excludeId) continue;

      final rowName = (row['name'] as String? ?? '').trim().toLowerCase();
      final rowEmail = (row['email'] as String? ?? '').trim().toLowerCase();
      final rowPhone =
      (row['phone'] as String? ?? '').replaceAll(RegExp(r'[^0-9]'), '');

      final sameEmail = trimmedEmail.isNotEmpty && rowEmail == trimmedEmail;
      final samePhone = normalizedPhone.isNotEmpty &&
          normalizedPhone.length >= 7 &&
          rowPhone == normalizedPhone;
      final sameName = trimmedName.isNotEmpty && rowName == trimmedName;

      if (sameEmail || samePhone || sameName) {
        matches.add(ClientModel.fromMap(id, row));
      }
    }

    return matches;
  }

  /// Archives a client instead of deleting it (GLOBAL_READINESS §1.I —
  /// prefer archive over delete). Archived clients disappear from the
  /// default client list and client picker, but their requests and history
  /// stay intact and reversible.
  Future<void> archiveClient(String id) async {
    await _client
        .from('clients')
        .update({'archived_at': DateTime.now().toIso8601String()}).eq('id', id);
  }

  Future<void> unarchiveClient(String id) async {
    await _client.from('clients').update({'archived_at': null}).eq('id', id);
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
        .eq('business_id', user.id)
        .filter('archived_at', 'is', null);

    return rows.length;
  }
}