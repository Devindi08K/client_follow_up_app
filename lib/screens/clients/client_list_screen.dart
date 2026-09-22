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

class _ClientListScreenState extends State<ClientListScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _clientService = ClientService();
  late final TabController _tabController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  List<ClientModel> _filter(List<ClientModel> clients) {
    if (_query.trim().isEmpty) return clients;
    final q = _query.trim().toLowerCase();
    return clients
        .where((c) =>
    c.name.toLowerCase().contains(q) ||
        c.email.toLowerCase().contains(q) ||
        c.phone.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _archive(ClientModel client) async {
    try {
      await _clientService.archiveClient(client.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${client.name} archived.'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _clientService.unarchiveClient(client.id),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not archive this client.'),
          backgroundColor: AppColors.rust,
        ),
      );
    }
  }

  Future<void> _unarchive(ClientModel client) async {
    try {
      await _clientService.unarchiveClient(client.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not unarchive this client.'),
          backgroundColor: AppColors.rust,
        ),
      );
    }
  }

  Future<void> _delete(ClientModel client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${client.name} permanently?'),
        content: const Text(
            'This can\'t be undone. Clients with existing requests can\'t be deleted — cancel or complete those first.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.rust)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _clientService.deleteClient(client.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: AppColors.rust,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Archived'),
          ],
        ),
      ),
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
              child: TabBarView(
                controller: _tabController,
                children: [
                  _ClientListTab(
                    stream: _clientService.streamClients(),
                    filter: _filter,
                    emptyText:
                    _query.isEmpty ? 'No active clients yet.' : 'No matches for "$_query".',
                    onTap: (c) => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ClientDetailScreen(client: c))),
                    trailingBuilder: (c) => IconButton(
                      tooltip: 'Archive',
                      icon: const Icon(Icons.archive_outlined),
                      onPressed: () => _archive(c),
                    ),
                  ),
                  _ClientListTab(
                    stream: _clientService.streamClients(includeArchived: true),
                    filter: _filter,
                    emptyText: _query.isEmpty ? 'No archived clients.' : 'No matches for "$_query".',
                    onTap: (c) => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => ClientDetailScreen(client: c))),
                    trailingBuilder: (c) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Unarchive',
                          icon: const Icon(Icons.unarchive_outlined),
                          onPressed: () => _unarchive(c),
                        ),
                        IconButton(
                          tooltip: 'Delete permanently',
                          icon: const Icon(Icons.delete_outline, color: AppColors.rust),
                          onPressed: () => _delete(c),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientListTab extends StatelessWidget {
  final Stream<List<ClientModel>> stream;
  final List<ClientModel> Function(List<ClientModel>) filter;
  final String emptyText;
  final void Function(ClientModel) onTap;
  final Widget Function(ClientModel) trailingBuilder;

  const _ClientListTab({
    required this.stream,
    required this.filter,
    required this.emptyText,
    required this.onTap,
    required this.trailingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ClientModel>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final clients = filter(snapshot.data!);
        if (clients.isEmpty) {
          return Center(child: Text(emptyText, style: TextStyle(color: AppColors.inkSoft)));
        }
        return ListView.builder(
          itemCount: clients.length,
          itemBuilder: (context, i) {
            final c = clients[i];
            return ListTile(
              title: Text(c.name),
              subtitle: Text(
                c.email.isNotEmpty ? c.email : (c.phone.isNotEmpty ? c.phone : 'No contact info'),
              ),
              trailing: trailingBuilder(c),
              onTap: () => onTap(c),
            );
          },
        );
      },
    );
  }
}