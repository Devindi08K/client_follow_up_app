import 'package:flutter/material.dart';
import '../../models/client.dart';
import '../../services/client_service.dart';
import 'client_detail_screen.dart';

class ClientListScreen extends StatelessWidget {
  const ClientListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: StreamBuilder<List<ClientModel>>(
        stream: ClientService().streamClients(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final clients = snapshot.data!;
          if (clients.isEmpty) {
            return const Center(child: Text('No clients yet.'));
          }
          return ListView.builder(
            itemCount: clients.length,
            itemBuilder: (context, i) {
              final c = clients[i];
              return ListTile(
                title: Text(c.name),
                subtitle: Text(c.email),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => ClientDetailScreen(client: c))),
              );
            },
          );
        },
      ),
    );
  }
}