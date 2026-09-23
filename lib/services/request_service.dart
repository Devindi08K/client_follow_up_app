import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/request_item_draft.dart';
import 'package:intl/intl.dart';
import 'retry_helper.dart';

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

  /// Returns this client's active (pending/overdue) requests whose title
  /// matches [title] (case/whitespace-insensitive) — GLOBAL_READINESS §1.H,
  /// "warn before accidentally creating a duplicate request."
  Future<List<Map<String, dynamic>>> findPossibleDuplicateRequests({
    required String clientId,
    required String title,
  }) async {
    final uid = _client.auth.currentUser!.id;
    final trimmedTitle = title.trim().toLowerCase();
    if (trimmedTitle.isEmpty) return [];

    final rows = await _client
        .from('requests')
        .select('id, title, status, created_at')
        .eq('business_id', uid)
        .eq('client_id', clientId)
        .inFilter('status', ['pending', 'overdue']);

    return List<Map<String, dynamic>>.from(rows)
        .where((r) =>
    (r['title'] as String? ?? '').trim().toLowerCase() == trimmedTitle)
        .toList();
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

    final requestRow = await withRetry(() => _client
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
        .single());

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
    await withRetry(() => _client.from('request_items').update({
      'status': received ? 'received' : 'missing',
      'received_at': received ? DateTime.now().toIso8601String() : null,
    }).eq('id', itemId));

    await _logFollowUp(
      requestId: requestId,
      action: received ? 'marked_received' : 'reopened',
    );

    await _recalculateCompletion(requestId);
  }

  /// Adds a new required item to an existing request (GLOBAL_READINESS §1.J
  /// — "item is added"). If the request had already been completed, adding
  /// a missing item resumes the follow-up workflow.
  Future<void> addRequestItem({
    required String requestId,
    required String name,
    String? instructions,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw Exception('Item name is required.');
    }

    await _client.from('request_items').insert({
      'request_id': requestId,
      'name': trimmedName,
      'instructions':
      (instructions == null || instructions.trim().isEmpty) ? null : instructions.trim(),
      'status': 'missing',
    });

    await _logFollowUp(requestId: requestId, action: 'item_added', notes: trimmedName);
    await _recalculateCompletion(requestId);
  }

  /// Removes a required item from an existing request (GLOBAL_READINESS
  /// §1.J — "item is removed"). Refuses to remove the last remaining item —
  /// a request must always have at least one required item.
  Future<void> removeRequestItem({
    required String requestId,
    required String itemId,
  }) async {
    final remaining =
    await _client.from('request_items').select('id').eq('request_id', requestId);

    if (remaining.length <= 1) {
      throw Exception('A request needs at least one item. Cancel the request instead.');
    }

    final item = await _client
        .from('request_items')
        .select('name')
        .eq('id', itemId)
        .maybeSingle();

    await _client.from('request_items').delete().eq('id', itemId);

    await _logFollowUp(
      requestId: requestId,
      action: 'item_removed',
      notes: item?['name'] as String?,
    );
    await _recalculateCompletion(requestId);
  }

  Future<void> _recalculateCompletion(String requestId) async {
    final items =
    await _client.from('request_items').select('status').eq('request_id', requestId);

    final allReceived = items.isNotEmpty && items.every((row) => row['status'] == 'received');

    final request = await _client
        .from('requests')
        .select('status, created_at, reminder_cadence, last_contacted_at')
        .eq('id', requestId)
        .maybeSingle();

    if (request == null) return;

    final currentStatus = request['status'] as String?;
    if (currentStatus == 'cancelled') return;

    if (allReceived && currentStatus != 'complete') {
      await _client.from('requests').update({
        'status': 'complete',
        'completed_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
    } else if (!allReceived && currentStatus == 'complete') {
      // An item was reopened, or a new missing item was added, after
      // completion — resume the workflow (Flow I) and schedule a fresh
      // follow-up from the reminder cadence.
      final createdAt = DateTime.parse(request['created_at'] as String);
      final cadence =
          (request['reminder_cadence'] as List?)?.map((e) => e as int).toList() ??
              defaultCadence;
      final lastContactedAt = request['last_contacted_at'] != null
          ? DateTime.parse(request['last_contacted_at'] as String)
          : null;
      final nextFollowUp = lastContactedAt != null
          ? _computeNextFollowUp(cadence, createdAt, lastContactedAt)
          : createdAt.add(Duration(days: cadence.first));

      await _client.from('requests').update({
        'status': 'pending',
        'completed_at': null,
        'next_follow_up_at': nextFollowUp?.toIso8601String(),
      }).eq('id', requestId);
    }
  }
  /// Restores a request to an explicit set of field values. Used to power
  /// "Undo" on reversible actions like mark contacted / cancel
  /// (GLOBAL_READINESS §1.AF).
  Future<void> revertRequestFields({
    required String requestId,
    required Map<String, dynamic> fields,
  }) async {
    await _client.from('requests').update(fields).eq('id', requestId);
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

    final request = await withRetry(() => _client
        .from('requests')
        .select('created_at, reminder_cadence, status')
        .eq('id', requestId)
        .single());

    final createdAt = DateTime.parse(request['created_at'] as String);
    final cadence =
        (request['reminder_cadence'] as List?)?.map((e) => e as int).toList() ??
            defaultCadence;
    final currentStatus = request['status'] as String?;
    final nextFollowUp = _computeNextFollowUp(cadence, createdAt, now);

    await withRetry(() => _client.from('requests').update({
      'last_contacted_at': now.toIso8601String(),
      'next_follow_up_at': nextFollowUp?.toIso8601String(),
      if (nextFollowUp == null && currentStatus != 'complete') 'status': 'overdue',
    }).eq('id', requestId));

    await withRetry(() => _client.from('follow_ups').insert({
      'business_id': uid,
      'request_id': requestId,
      'channel': channel,
      'action': 'contacted',
    }));
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
  /// Reopens a cancelled request (Flow J / B6 — Reopen), resuming the
  /// follow-up workflow. Recomputes the next follow-up date from the
  /// reminder cadence, based on whichever is later: creation, or the last
  /// time the client was actually contacted.
  Future<void> reopenRequest(String requestId) async {
    final request = await _client
        .from('requests')
        .select('created_at, reminder_cadence, last_contacted_at')
        .eq('id', requestId)
        .single();

    final createdAt = DateTime.parse(request['created_at'] as String);
    final cadence =
        (request['reminder_cadence'] as List?)?.map((e) => e as int).toList() ??
            defaultCadence;
    final lastContactedAt = request['last_contacted_at'] != null
        ? DateTime.parse(request['last_contacted_at'] as String)
        : null;

    final nextFollowUp = lastContactedAt != null
        ? _computeNextFollowUp(cadence, createdAt, lastContactedAt)
        : createdAt.add(Duration(days: cadence.first));

    await _client.from('requests').update({
      'status': 'pending',
      'cancelled_at': null,
      'next_follow_up_at': nextFollowUp?.toIso8601String(),
    }).eq('id', requestId);

    await _logFollowUp(requestId: requestId, action: 'reopened');
  }
  /// Extends (or shortens) a request's due date (B6 — Extend Due Date).
  /// If the request had been flagged overdue and the new date is in the
  /// future, it's un-flagged back to pending.
  Future<void> extendDueDate({
    required String requestId,
    required DateTime newDueDate,
  }) async {
    final request = await _client
        .from('requests')
        .select('status')
        .eq('id', requestId)
        .single();

    final currentStatus = request['status'] as String?;
    final updates = <String, dynamic>{
      'due_date': newDueDate.toIso8601String(),
    };

    if (currentStatus == 'overdue' && newDueDate.isAfter(DateTime.now())) {
      updates['status'] = 'pending';
    }

    await _client.from('requests').update(updates).eq('id', requestId);

    await _logFollowUp(
      requestId: requestId,
      action: 'due_date_extended',
      notes: 'New due date: ${_formatDate(newDueDate)}',
    );
  }

  /// Updates a single request's reminder cadence (GLOBAL_READINESS §1.J —
  /// "reminder cadence changes") and recalculates its next follow-up date
  /// from the new schedule, same logic as markContacted/reopenRequest.
  Future<void> updateReminderCadence({
    required String requestId,
    required List<int> cadence,
  }) async {
    if (cadence.isEmpty) {
      throw Exception('Choose at least one reminder day.');
    }
    final sorted = [...cadence]..sort();

    final request = await _client
        .from('requests')
        .select('created_at, last_contacted_at, status')
        .eq('id', requestId)
        .single();

    final createdAt = DateTime.parse(request['created_at'] as String);
    final lastContactedAt = request['last_contacted_at'] != null
        ? DateTime.parse(request['last_contacted_at'] as String)
        : null;
    final currentStatus = request['status'] as String?;

    final nextFollowUp = lastContactedAt != null
        ? _computeNextFollowUp(sorted, createdAt, lastContactedAt)
        : createdAt.add(Duration(days: sorted.first));

    await _client.from('requests').update({
      'reminder_cadence': sorted,
      'next_follow_up_at': nextFollowUp?.toIso8601String(),
      if (nextFollowUp == null && currentStatus == 'pending') 'status': 'overdue',
    }).eq('id', requestId);

    await _logFollowUp(
      requestId: requestId,
      action: 'cadence_updated',
      notes: 'New schedule: Day ${sorted.join(', ')}',
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat.yMMMd().format(date);
  }
}