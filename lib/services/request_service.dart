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
  Stream<List<Map<String, dynamic>>> streamFollowUpHistory(String requestId) {
    return _client
        .from('follow_ups')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('created_at')
        .map((rows) => rows.reversed.toList());
  }

  /// One-time fetch of every request for the dashboard, with the parent
  /// client and item statuses embedded so stats can be computed client-side.
  /// This is "Level 1" automation per TECHNICAL_ARCHITECTURE §17 — no
  /// scheduled backend function required for the MVP.
  Future<List<Map<String, dynamic>>> fetchRequestsOverview() async {
    final uid = _client.auth.currentUser!.id;
    final rows = await _client
        .from('requests')
        .select('*, clients(id, name, email, phone), request_items(id, name, status)')
        .eq('business_id', uid)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Fetch a single request with its client, for the Request Detail screen.
  Future<Map<String, dynamic>?> fetchRequestDetail(String requestId) async {
    return _client
        .from('requests')
        .select('*, clients(id, name, email, phone)')
        .eq('id', requestId)
        .maybeSingle();
  }

  Future<String> createRequest({
    required String clientId,
    required List<RequestItemDraft> items,
    String title = 'Request',
    String? description,
    DateTime? dueDate,
    List<int>? reminderCadence,
  }) async {
    final uid = _client.auth.currentUser!.id;
    final cadence = (reminderCadence == null || reminderCadence.isEmpty)
        ? defaultCadence
        : (List<int>.from(reminderCadence)..sort());
    final now = DateTime.now();
    final nextFollowUpAt = now.add(Duration(days: cadence.first));

    final requestRow = await _client
        .from('requests')
        .insert({
      'business_id': uid,
      'client_id': clientId,
      'title': title.trim().isEmpty ? 'Request' : title.trim(),
      'description': (description == null || description.trim().isEmpty)
          ? null
          : description.trim(),
      'status': 'pending',
      'due_date': dueDate?.toIso8601String(),
      'reminder_cadence': cadence,
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

  /// Marks a single item received or missing again (Flow G / Flow I), then
  /// checks whether the whole request should flip to "complete" or reopen.
  Future<void> setItemStatus({
    required String requestId,
    required String itemId,
    required bool received,
  }) async {
    await _client.from('request_items').update({
      'status': received ? 'received' : 'missing',
      'received_at': received ? DateTime.now().toIso8601String() : null,
    }).eq('id', itemId);

    await _logFollowUp(
      requestId: requestId,
      action: received ? 'marked_received' : 'reopened',
    );

    await _recalculateCompletion(requestId);
  }

  Future<void> _recalculateCompletion(String requestId) async {
    final items =
    await _client.from('request_items').select('status').eq('request_id', requestId);

    final allReceived = items.isNotEmpty && items.every((row) => row['status'] == 'received');

    final request =
    await _client.from('requests').select('status').eq('id', requestId).maybeSingle();

    final currentStatus = request?['status'] as String?;
    if (currentStatus == 'cancelled') return;

    if (allReceived && currentStatus != 'complete') {
      await _client.from('requests').update({
        'status': 'complete',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
    } else if (!allReceived && currentStatus == 'complete') {
      // An item was reopened after completion — resume the workflow (Flow I).
      await _client.from('requests').update({
        'status': 'pending',
        'completed_at': null,
      }).eq('id', requestId);
    }
  }

  /// Records that the business contacted the client (Flow F), then
  /// recalculates the next follow-up date from the configured reminder
  /// cadence. Mirrors the logic the optional Edge Function would run later.
  Future<void> markContacted({
    required String requestId,
    required String channel,
  }) async {
    final uid = _client.auth.currentUser!.id;
    final now = DateTime.now();

    final request = await _client
        .from('requests')
        .select('created_at, reminder_cadence, status')
        .eq('id', requestId)
        .single();

    final createdAt = DateTime.parse(request['created_at'] as String);
    final cadence =
        (request['reminder_cadence'] as List?)?.map((e) => e as int).toList() ??
            defaultCadence;
    final currentStatus = request['status'] as String?;
    final nextFollowUp = _computeNextFollowUp(cadence, createdAt, now);

    await _client.from('requests').update({
      'last_contacted_at': now.toIso8601String(),
      'next_follow_up_at': nextFollowUp?.toIso8601String(),
      if (nextFollowUp == null && currentStatus != 'complete') 'status': 'overdue',
    }).eq('id', requestId);

    await _client.from('follow_ups').insert({
      'business_id': uid,
      'request_id': requestId,
      'channel': channel,
      'action': 'contacted',
    });
  }

  DateTime? _computeNextFollowUp(List<int> cadence, DateTime createdAt, DateTime now) {
    final sorted = [...cadence]..sort();
    final daysSinceCreation = now.difference(createdAt).inHours / 24;

    for (final day in sorted) {
      if (day > daysSinceCreation + 0.5) {
        return createdAt.add(Duration(days: day));
      }
    }
    return null;
  }

  Future<void> logReminderGenerated(String requestId) {
    return _logFollowUp(requestId: requestId, action: 'generated');
  }

  Future<void> _logFollowUp({
    required String requestId,
    required String action,
    String? channel,
    String? notes,
  }) async {
    final uid = _client.auth.currentUser!.id;
    await _client.from('follow_ups').insert({
      'business_id': uid,
      'request_id': requestId,
      'channel': channel,
      'action': action,
      'notes': notes,
    });
  }

  Future<void> completeRequest(String requestId) async {
    await _client.from('requests').update({
      'status': 'complete',
      'completed_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  Future<void> cancelRequest(String requestId) async {
    await _client.from('requests').update({
      'status': 'cancelled',
      'cancelled_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }
}