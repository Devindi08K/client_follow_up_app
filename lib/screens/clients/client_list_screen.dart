import 'package:flutter/material.dart';
import '../../models/client.dart';
import '../../services/client_service.dart';
import '../../theme/app_theme.dart';
import 'client_detail_screen.dart';

class ClientListScreen extends StatefulWidget {
  const ClientListScreen({super.key});

  @override
  State<ClientListScreen> createState() => _ClientListScreenState();
}

class _ClientListScreenState extends State<ClientListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ClientModel> _filter(List<ClientModel> clients) {
    if (_query.trim().isEmpty) return clients;
    final q = _query.trim().toLowerCase();
    return clients
        .where((c) =>
    c.name.toLowerCase().contains(q) || c.email.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clients')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search clients',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _searchController.clear();
                      _query = '';
                    }),
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ClientModel>>(
                stream: ClientService().streamClients(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final clients = _filter(snapshot.data!);
                  if (clients.isEmpty) {
                    return Center(
                      child: Text(
                        _query.isEmpty ? 'No clients yet.' : 'No matches for "$_query".',
                        style: TextStyle(color: AppColors.inkSoft),
                      ),
                    );
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
            ),
          ],
        ),
      ),
    );
  }
}