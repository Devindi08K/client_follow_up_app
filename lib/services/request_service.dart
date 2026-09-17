// lib/services/request_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/request_item_draft.dart';

class RequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<List<Map<String, dynamic>>> streamAllRequests() {
    final uid = _auth.currentUser!.uid;
    return _firestore
        .collectionGroup('requests')
        .where('businessId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => {'id': d.id, 'ref': d.reference, ...d.data()})
        .toList());
  }

  Stream<List<Map<String, dynamic>>> streamRequestsForClient(String clientId) {
    final uid = _auth.currentUser!.uid;
    return _firestore
        .collection('businesses').doc(uid)
        .collection('clients').doc(clientId)
        .collection('requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
        .map((d) => {'id': d.id, 'ref': d.reference, ...d.data()})
        .toList());
  }

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
      'businessId': uid,                    // <-- ADD THIS LINE
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'dueDate': null,
      'reminderCadence': defaultCadence,
      'lastReminderSentAt': null,
      'nextReminderDueAt': Timestamp.fromDate(nextReminderDueAt),
      'secureToken': secureToken,
      'tokenExpiresAt': Timestamp.fromDate(tokenExpiresAt),
      'businessId': uid,      // NEW — required by the collection-group rule above
      'clientId': clientId,   // NEW — lets Request Detail screen know its client
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
    debugPrint('✅ Request created at: ${requestDoc.path}');
    return requestDoc.id;
  }
}