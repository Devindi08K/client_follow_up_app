// lib/services/client_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/client.dart';

class ClientService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _clientsRef {
    final uid = _auth.currentUser!.uid;
    return _firestore.collection('businesses').doc(uid).collection('clients');
  }

  Stream<List<ClientModel>> streamClients() {
    return _clientsRef.orderBy('name').snapshots().map((snap) => snap.docs
        .map((doc) => ClientModel.fromMap(doc.id, doc.data()))
        .toList());
  }

  Future<ClientModel> createClient({
    required String name,
    required String email,
  }) async {
    final doc = await _clientsRef.add({
      'name': name.trim(),
      'email': email.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return ClientModel(id: doc.id, name: name.trim(), email: email.trim());
  }
}