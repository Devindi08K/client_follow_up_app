// lib/services/request_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/request_item_draft.dart';

class RequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const List<int> defaultCadence = [1, 3, 7];

  Future<String> createRequest({
    required String clientId,
    required List<RequestItemDraft> items,
  }) async {
    final uid = _auth.currentUser!.uid;
    final requestsRef = _firestore
        .collection('businesses')
        .doc(uid)
        .collection('clients')
        .doc(clientId)
        .collection('requests');

    final requestDoc = requestsRef.doc();
    final secureToken = requestDoc.id; // unguessable Firestore ID, doubles as token

    final now = DateTime.now();
    final nextReminderDueAt = now.add(const Duration(days: 1));
    final tokenExpiresAt = now.add(const Duration(days: 90));

    final batch = _firestore.batch();

    batch.set(requestDoc, {
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'dueDate': null,
      'reminderCadence': defaultCadence,
      'lastReminderSentAt': null,
      'nextReminderDueAt': Timestamp.fromDate(nextReminderDueAt),
      'secureToken': secureToken,
      'tokenExpiresAt': Timestamp.fromDate(tokenExpiresAt),
    });

    for (final item in items) {
      final itemDoc = requestDoc.collection('items').doc();
      batch.set(itemDoc, {
        'name': item.name.trim(),
        'instructions':
        item.instructions.trim().isEmpty ? null : item.instructions.trim(),
        'type': item.type,
        'status': 'missing',
        'fileUrl': null,
        'textAnswer': null,
        'submittedAt': null,
      });
    }

    await batch.commit();
    return requestDoc.id;
  }
}