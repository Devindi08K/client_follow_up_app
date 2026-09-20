import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/request_item_draft.dart';

class RequestService {
  final SupabaseClient _client = Supabase.instance.client;

  static const List<int> defaultCadence = [1, 3, 7];

  Stream<List<Map<String, dynamic>>> streamAllRequests() {
    final uid = _client.auth.currentUser!.id;

    return _client
        .from('requests')
        .stream(primaryKey: ['id'])
        .eq('business_id', uid)
        .order('created_at')
        .map((rows) => rows.reversed.toList());
  }

  Stream<List<Map<String, dynamic>>> streamRequestsForClient(String clientId) {
    return _client
        .from('requests')
        .stream(primaryKey: ['id'])
        .eq('client_id', clientId)
        .order('created_at')
        .map((rows) => rows.reversed.toList());
  }

  Stream<List<Map<String, dynamic>>> streamRequestItems(String requestId) {
    return _client
        .from('request_items')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('created_at');
  }

  Future<String> createRequest({
    required String clientId,
    required List<RequestItemDraft> items,
    String title = 'Request',
  }) async {
    final uid = _client.auth.currentUser!.id;
    final now = DateTime.now();
    final nextFollowUpAt = now.add(const Duration(days: 1));

    final requestRow = await _client
        .from('requests')
        .insert({
      'business_id': uid,
      'client_id': clientId,
      'title': title,
      'status': 'pending',
      'reminder_cadence': defaultCadence,
      'next_follow_up_at': nextFollowUpAt.toIso8601String(),
    })
        .select()
        .single();

    final requestId = requestRow['id'] as String;

    if (items.isNotEmpty) {
      await _client.from('request_items').insert(
        items
            .map((item) => {
          'request_id': requestId,
          'name': item.name.trim(),
          'instructions':
          item.instructions.trim().isEmpty ? null : item.instructions.trim(),
          'status': 'missing',
        })
            .toList(),
      );
    }

    return requestId;
  }
}