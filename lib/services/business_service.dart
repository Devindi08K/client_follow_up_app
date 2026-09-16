import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BusinessService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> createBusinessProfile({required String businessName}) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    await _firestore.collection('businesses').doc(user.uid).set({
      'name': businessName.trim(),
      'email': user.email,
      'logoUrl': null,
      'defaultReminderCadence': [1, 3, 7],
      'plan': 'free',
      'revenueCatAppUserId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamBusinessProfile() {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    return _firestore.collection('businesses').doc(user.uid).snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getBusinessProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('No authenticated user found.');
    }

    return _firestore.collection('businesses').doc(user.uid).get();
  }
}
