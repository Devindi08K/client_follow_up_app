import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class RequestDetailScreen extends StatelessWidget {
  final DocumentReference<Map<String, dynamic>> requestRef;
  final String clientName;
  const RequestDetailScreen({super.key, required this.requestRef, required this.clientName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(clientName)),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(   // add the generic
        stream: requestRef.collection('items').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!.docs;
          if (items.isEmpty) {
            return const Center(child: Text('No items on this request.'));
          }
          return ListView(
            children: items.map((doc) {
              final data = doc.data();   // no more "as Map<String,dynamic>" needed — already typed
              return ListTile(
                title: Text(data['name'] ?? ''),
                subtitle: Text(data['instructions'] ?? ''),
                trailing: Text(data['status'] ?? 'missing'),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}