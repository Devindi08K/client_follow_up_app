import 'package:flutter/material.dart';

import '../../services/request_service.dart';

class RequestDetailScreen extends StatelessWidget {
  final String requestId;
  final String clientName;

  const RequestDetailScreen({
    super.key,
    required this.requestId,
    required this.clientName,
  });

  @override
  Widget build(BuildContext context) {
    final requestService = RequestService();

    return Scaffold(
      appBar: AppBar(title: Text(clientName)),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: requestService.streamRequestItems(requestId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No items on this request.'));
          }

          return ListView(
            children: items.map((data) {
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