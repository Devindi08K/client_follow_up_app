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
    setState(() => _creating = true);

    try {
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
                        style: TextStyle(color: AppColors.inkSoft)),
                  );
                }

                return ListView.separated(
                  itemCount: clients.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    final selected = widget.selectedClient?.id == client.id;

                    return ListTile(
                      tileColor:
                      selected ? AppColors.sageLight : AppColors.paperRaised,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(color: AppColors.line),
                      ),
                      title: Text(client.name),
                      subtitle: Text(client.email),
                      trailing: selected
                          ? const Icon(Icons.check_circle, color: AppColors.forest)
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
                    decoration: const InputDecoration(labelText: 'Client email'),
                    validator: (v) {
                      final email = v?.trim() ?? '';
                      if (email.isEmpty) return 'Enter an email';
                      if (!email.contains('@')) return 'Enter a valid email';
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