// lib/screens/requests/new_request_wizard/step1_select_client.dart
import 'package:flutter/material.dart';

import '../../../models/client.dart';
import '../../../services/client_service.dart';
import '../../../theme/app_theme.dart';

class Step1SelectClient extends StatefulWidget {
  final ClientModel? selectedClient;
  final ValueChanged<ClientModel> onClientSelected;

  const Step1SelectClient({
    super.key,
    required this.selectedClient,
    required this.onClientSelected,
  });

  @override
  State<Step1SelectClient> createState() => _Step1SelectClientState();
}

class _Step1SelectClientState extends State<Step1SelectClient> {
  final _clientService = ClientService();
  bool _showNewClientForm = false;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _createClient() async {
    if (!_formKey.currentState!.validate()) return;

    if (_emailController.text.trim().isEmpty &&
        _phoneController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least an email or a phone number.')),
      );
      return;
    }

    setState(() => _creating = true);

    try {
      final duplicates = await _clientService.findPossibleDuplicates(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
      );

      if (duplicates.isNotEmpty) {
        setState(() => _creating = false);
        if (!mounted) return;
        final proceed = await _confirmDuplicate(duplicates);
        if (proceed != true) return;
        if (!mounted) return;
        setState(() => _creating = true);
      }

      final client = await _clientService.createClient(
        name: _nameController.text,
        email: _emailController.text,
        phone: _phoneController.text,
      );
      widget.onClientSelected(client);

      if (!mounted) return;
      setState(() {
        _showNewClientForm = false;
        _nameController.clear();
        _emailController.clear();
        _phoneController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not create client: $e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<bool?> _confirmDuplicate(List<ClientModel> duplicates) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Possible duplicate client'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This looks similar to an existing client:'),
            const SizedBox(height: 12),
            ...duplicates.take(3).map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '• ${c.name}'
                    '${c.email.isNotEmpty ? ' — ${c.email}' : ''}'
                    '${c.phone.isNotEmpty ? ' — ${c.phone}' : ''}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add anyway'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Who is this request for?',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<ClientModel>>(
              stream: _clientService.streamClients(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final clients = snapshot.data!;

                if (clients.isEmpty && !_showNewClientForm) {
                  return Center(
                    child: Text('No clients yet. Add your first one below.',
                        style: TextStyle(color: context.palette.textSecondary)),
                  );
                }

                return ListView.separated(
                  itemCount: clients.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    final selected = widget.selectedClient?.id == client.id;

                    return ListTile(
                      tileColor:
                      selected ? context.palette.surface2 : context.palette.surface1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(color: context.palette.border),
                      ),
                      title: Text(client.name),
                      subtitle: Text(client.email),
                      trailing: selected
                          ? const Icon(Icons.check_circle, color: AppStatusColors.forest)
                          : null,
                      onTap: () => widget.onClientSelected(client),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          if (_showNewClientForm)
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Client name'),
                    validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Client email (optional)'),
                    validator: (v) {
                      final email = v?.trim() ?? '';
                      if (email.isNotEmpty && !email.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'Client phone (optional)'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _creating
                              ? null
                              : () => setState(() => _showNewClientForm = false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _creating ? null : _createClient,
                          child: _creating
                              ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Add client'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () => setState(() => _showNewClientForm = true),
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('New client'),
            ),
        ],
      ),
    );
  }
}