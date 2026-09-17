import 'package:flutter/material.dart';
import '../../models/client.dart';
import '../../services/request_service.dart';
import '../requests/request_detail_screen.dart';

class ClientDetailScreen extends StatelessWidget {
  final ClientModel client;
  const ClientDetailScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(client.name)),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: RequestService().streamRequestsForClient(client.id),
        builder: (context, snapshot) {
          final requests = snapshot.data ?? [];
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (requests.isEmpty) {
            return const Center(child: Text('No requests yet for this client.'));
          }
          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, i) {
              final r = requests[i];
              return ListTile(
                title: Text('Request ${r['id']}'),
                subtitle: Text('Status: ${r['status']}'),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => RequestDetailScreen(
                        requestRef: r['ref'], clientName: client.name))),
              );
            },
          );
        },
      ),
    );
  }
}