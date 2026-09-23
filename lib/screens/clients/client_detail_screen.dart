import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/client.dart';
import '../../services/client_service.dart';
import '../../services/request_service.dart';
import '../../theme/app_theme.dart';
import '../requests/new_request_wizard/new_request_wizard_screen.dart';
import '../requests/request_detail_screen.dart';
import '../../widgets/phone_input_field.dart';

/// B4 — Client Detail screen.
class ClientDetailScreen extends StatefulWidget {
  final ClientModel client;

  const ClientDetailScreen({
    super.key,
    required this.client,
  });

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen>
    with SingleTickerProviderStateMixin {
  final _clientService = ClientService();
  final _requestService = RequestService();

  late ClientModel _client;
  late TabController _tabController;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppStatusColors.rust),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppStatusColors.forest),
    );
  }

  Future<void> _openNewRequest() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NewRequestWizardScreen(initialClient: _client),
      ),
    );
    if (created == true) {
      setState(() {}); // refresh streams
    }
  }

  Future<void> _openRequest(String requestId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RequestDetailScreen(requestId: requestId)),
    );
  }

  static const Map<String, String> _contactOptions = {
    'none': 'No preference',
    'email': 'Email',
    'whatsapp': 'WhatsApp',
    'phone': 'Phone',
  };

  Future<void> _editClient() async {
    final nameController = TextEditingController(text: _client.name);
    final emailController = TextEditingController(text: _client.email);
    final phoneController = TextEditingController(text: _client.phone);
    final formKey = GlobalKey<FormState>();
    String preferredContact = _client.preferredContact;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Edit client',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Client name'),
                      validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Client email (optional)'),
                      validator: (v) {
                        final email = v?.trim() ?? '';
                        if (email.isNotEmpty && !email.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    PhoneInputField(
                      initialValue: phoneController.text,
                      onChanged: (value) => phoneController.text = value,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: preferredContact,
                      decoration: const InputDecoration(labelText: 'Preferred contact method'),
                      items: _contactOptions.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) =>
                          setModalState(() => preferredContact = v ?? 'none'),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        if (emailController.text.trim().isEmpty &&
                            phoneController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Add at least an email or a phone number.')),
                          );
                          return;
                        }
                        Navigator.pop(context, true);
                      },
                      child: const Text('Save changes'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (saved != true) return;

    setState(() => _busy = true);
    try {
      final duplicates = await _clientService.findPossibleDuplicates(
        name: nameController.text,
        email: emailController.text,
        phone: phoneController.text,
        excludeId: _client.id,
      );

      if (duplicates.isNotEmpty) {
        setState(() => _busy = false);
        if (!mounted) return;
        final proceed = await _confirmDuplicate(duplicates);
        if (proceed != true) return;
        if (!mounted) return;
        setState(() => _busy = true);
      }

      final updated = await _clientService.updateClient(
        id: _client.id,
        name: nameController.text,
        email: emailController.text,
        phone: phoneController.text,
        preferredContact: preferredContact,
      );
      if (!mounted) return;
      setState(() => _client = updated);
      _showSuccess('Client updated.');
    } catch (e) {
      _showError('Could not save changes: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
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
            const Text('This looks similar to another client:'),
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
            child: const Text('Save anyway'),
          ),
        ],
      ),
    );
  }


  Future<void> _toggleArchived() async {
    final archiving = !_client.isArchived;

    if (archiving) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Archive ${_client.name}?'),
          content: const Text(
              'Archived clients are hidden from your client list and can\'t receive new requests, but their history stays intact. You can unarchive anytime.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true), child: const Text('Archive')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _busy = true);
    try {
      if (archiving) {
        await _clientService.archiveClient(_client.id);
      } else {
        await _clientService.unarchiveClient(_client.id);
      }
      if (!mounted) return;
      setState(() {
        _client = ClientModel(
          id: _client.id,
          name: _client.name,
          email: _client.email,
          phone: _client.phone,
          preferredContact: _client.preferredContact,
          archivedAt: archiving ? DateTime.now() : null,
        );
      });

      if (archiving) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Client archived.'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                await _clientService.unarchiveClient(_client.id);
                if (!mounted) return;
                setState(() {
                  _client = ClientModel(
                    id: _client.id,
                    name: _client.name,
                    email: _client.email,
                    phone: _client.phone,
                    preferredContact: _client.preferredContact,
                    archivedAt: null,
                  );
                });
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        _showSuccess('Client unarchived.');
      }
    } catch (_) {
      _showError('Could not update this client.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteClient() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${_client.name}?'),
        content: const Text(
            'This removes the client permanently. Clients with existing requests can\'t be deleted — cancel or complete those first.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppStatusColors.rust)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _clientService.deleteClient(_client.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }

  List<Map<String, dynamic>> _filter(
      List<Map<String, dynamic>> rows, Set<String> statuses) {
    return rows.where((r) => statuses.contains(r['status'] as String? ?? 'pending')).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_client.name),
        actions: [
          IconButton(
            tooltip: _client.isArchived ? 'Unarchive client' : 'Archive client',
            icon: Icon(_client.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
            onPressed: _busy ? null : _toggleArchived,
          ),
          IconButton(
            tooltip: 'Edit client',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _busy ? null : _editClient,
          ),
          IconButton(
            tooltip: 'Delete client',
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : _deleteClient,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.palette.surface1,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_client.email.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.email_outlined, size: 18, color: context.palette.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_client.email)),
                        ],
                      ),
                    if (_client.phone.isNotEmpty) ...[
                      if (_client.email.isNotEmpty) const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 18, color: context.palette.primary),
                          const SizedBox(width: 8),
                          Text(_client.phone),
                        ],
                      ),
                    ],
                    if (_client.email.isEmpty && _client.phone.isEmpty)
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: context.palette.textSecondary),
                          const SizedBox(width: 8),
                          Text('No contact info on file',
                              style: TextStyle(color: context.palette.textSecondary)),
                        ],
                      ),
                    const SizedBox(height: 14),
                    if (_client.isArchived)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: context.palette.surface2,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.archive_outlined, size: 18, color: context.palette.primary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'This client is archived. Unarchive to create a new request.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: _busy ? null : _openNewRequest,
                        icon: const Icon(Icons.add),
                        label: const Text('New request'),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _requestService.streamRequestsForClient(_client.id),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = snapshot.data!;

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _RequestList(
                        rows: _filter(rows, {'pending', 'overdue'}),
                        emptyText: 'No active requests for this client.',
                        onTap: _openRequest,
                        parseDate: _parseDate,
                      ),
                      _RequestList(
                        rows: _filter(rows, {'complete'}),
                        emptyText: 'No completed requests yet.',
                        onTap: _openRequest,
                        parseDate: _parseDate,
                      ),
                      _RequestList(
                        rows: _filter(rows, {'cancelled'}),
                        emptyText: 'No cancelled requests.',
                        onTap: _openRequest,
                        parseDate: _parseDate,
                      ),
                    ],
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

class _RequestList extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String emptyText;
  final void Function(String requestId) onTap;
  final DateTime? Function(dynamic) parseDate;

  const _RequestList({
    required this.rows,
    required this.emptyText,
    required this.onTap,
    required this.parseDate,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(emptyText, style: TextStyle(color: context.palette.textSecondary)),
        ),
      );
    }

    final dateFormat = DateFormat.yMMMd();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = rows[index];
        final status = row['status'] as String? ?? 'pending';
        final dueDate = parseDate(row['due_date']);

        return Container(
          decoration: BoxDecoration(
            color: context.palette.surface1,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: context.palette.border),
          ),
          child: ListTile(
            title: Text(row['title'] as String? ?? 'Request',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: dueDate != null ? Text('Due ${dateFormat.format(dueDate)}') : null,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppStatusColors.forStatus(status).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status[0].toUpperCase() + status.substring(1),
                style: TextStyle(
                  color: AppStatusColors.forStatus(status),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            onTap: () => onTap(row['id'] as String),
          ),
        );
      },
    );
  }
}