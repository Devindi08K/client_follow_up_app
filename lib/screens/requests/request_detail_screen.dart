import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/message_service.dart';
import '../../services/request_service.dart';
import '../../theme/app_theme.dart';
import 'message_screen.dart';
import 'follow_up_history_screen.dart';

/// B6 — Request Detail screen.
class RequestDetailScreen extends StatefulWidget {
  final String requestId;

  const RequestDetailScreen({super.key, required this.requestId});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _requestService = RequestService();
  final _messageService = MessageService();

  Map<String, dynamic>? _request;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _requestService.fetchRequestDetail(widget.requestId);
      if (!mounted) return;
      setState(() {
        _request = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Could not load this request.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.rust),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.forest),
    );
  }

  /// Shows a confirmation with an inline Undo action (GLOBAL_READINESS
  /// §1.AF). [onUndo] should restore the exact prior state, not just
  /// perform the opposite action, since the two aren't always symmetric.
  void _showUndoSnackBar({
    required String message,
    required Future<void> Function() onUndo,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;
            onUndo();
          },
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Map<String, dynamic> get _clientData =>
      (_request?['clients'] as Map<String, dynamic>?) ?? const {};

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }

  Future<void> _openGenerateReminder(List<Map<String, dynamic>> items) async {
    final missing = items.where((i) => i['status'] != 'received').toList();

    if (missing.isEmpty) {
      _showError('Every item has already been received.');
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MessageScreen(
          requestId: widget.requestId,
          clientName: _clientData['name'] as String? ?? 'there',
          clientEmail: _clientData['email'] as String? ?? '',
          clientPhone: _clientData['phone'] as String? ?? '',
          requestTitle: _request?['title'] as String? ?? 'Request',
          missingItemNames: missing.map((i) => i['name'] as String? ?? '').toList(),
          dueDate: _parseDate(_request?['due_date']),
          alreadyContacted: _request?['last_contacted_at'] != null,
        ),
      ),
    );

    if (result == true) {
      _load();
    }
  }

  Future<void> _markContacted() async {
    final channel = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('How did you contact the client?',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Email'),
              onTap: () => Navigator.pop(context, 'email'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('WhatsApp'),
              onTap: () => Navigator.pop(context, 'whatsapp'),
            ),
            ListTile(
              leading: const Icon(Icons.call_outlined),
              title: const Text('Phone'),
              onTap: () => Navigator.pop(context, 'phone'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_note_outlined),
              title: const Text('Other / manual'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
          ],
        ),
      ),
    );

    if (channel == null) return;

    final previousStatus = _request?['status'] as String?;
    final previousLastContacted = _request?['last_contacted_at'];
    final previousNextFollowUp = _request?['next_follow_up_at'];

    setState(() => _busy = true);
    try {
      await _requestService.markContacted(requestId: widget.requestId, channel: channel);
      await _load();
      if (!mounted) return;
      _showUndoSnackBar(
        message: 'Marked as contacted.',
        onUndo: () async {
          await _requestService.revertRequestFields(
            requestId: widget.requestId,
            fields: {
              'status': previousStatus,
              'last_contacted_at': previousLastContacted,
              'next_follow_up_at': previousNextFollowUp,
            },
          );
          await _load();
        },
      );
    } catch (_) {
      _showError('Could not save this. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _callClient() async {
    final phone = _clientData['phone'] as String? ?? '';
    final opened = await _messageService.openDialer(phone);
    if (!opened && mounted) {
      _showError('No phone number saved for this client.');
    }
  }

  Future<void> _toggleItem(Map<String, dynamic> item) async {
    final received = item['status'] != 'received';
    final itemId = item['id'] as String;

    setState(() => _busy = true);
    try {
      await _requestService.setItemStatus(
        requestId: widget.requestId,
        itemId: itemId,
        received: received,
      );
      await _load();
      if (!mounted) return;
      _showUndoSnackBar(
        message: received ? 'Marked as received.' : 'Marked as missing.',
        onUndo: () async {
          await _requestService.setItemStatus(
            requestId: widget.requestId,
            itemId: itemId,
            received: !received,
          );
          await _load();
        },
      );
    } catch (_) {
      _showError('Could not update this item.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _completeRequest() async {
    setState(() => _busy = true);
    try {
      await _requestService.completeRequest(widget.requestId);
      _showSuccess('Request marked complete.');
      await _load();
    } catch (_) {
      _showError('Could not complete this request.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _extendDueDate() async {
    final currentDue = _parseDate(_request?['due_date']);
    final baseline = (currentDue == null || currentDue.isBefore(DateTime.now()))
        ? DateTime.now()
        : currentDue;

    final picked = await showDatePicker(
      context: context,
      initialDate: baseline.add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      await _requestService.extendDueDate(requestId: widget.requestId, newDueDate: picked);
      _showSuccess('Due date updated.');
      await _load();
    } catch (_) {
      _showError('Could not update the due date.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addItem() async {
    final nameController = TextEditingController();
    final instructionsController = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Item name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: instructionsController,
              decoration: const InputDecoration(labelText: 'Instructions (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (added != true || nameController.text.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      await _requestService.addRequestItem(
        requestId: widget.requestId,
        name: nameController.text,
        instructions: instructionsController.text,
      );
      _showSuccess('Item added.');
      await _load();
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeItem(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove "${item['name']}"?'),
        content: const Text('This removes the item from the request permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.rust)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _requestService.removeRequestItem(
        requestId: widget.requestId,
        itemId: item['id'] as String,
      );
      _showSuccess('Item removed.');
      await _load();
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editCadence() async {
    final current =
        (_request?['reminder_cadence'] as List?)?.map((e) => e as int).toList() ??
            List<int>.from(RequestService.defaultCadence);
    final controller = TextEditingController(text: current.join(', '));

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit reminder schedule'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Days after creation, comma-separated',
            hintText: 'e.g. 1, 3, 7',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save')),
        ],
      ),
    );

    if (result == null) return;

    final parsed = result
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .where((n) => n > 0)
        .toSet()
        .toList()
      ..sort();

    if (parsed.isEmpty) return;

    setState(() => _busy = true);
    try {
      await _requestService.updateReminderCadence(requestId: widget.requestId, cadence: parsed);
      _showSuccess('Reminder schedule updated.');
      await _load();
    } catch (_) {
      _showError('Could not update the reminder schedule.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text(
            'No further follow-ups will be sent. This stays visible in your history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep request'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final previousStatus = _request?['status'] as String?;

    setState(() => _busy = true);
    try {
      await _requestService.cancelRequest(widget.requestId);
      await _load();
      if (!mounted) return;
      _showUndoSnackBar(
        message: 'Request cancelled.',
        onUndo: () async {
          await _requestService.revertRequestFields(
            requestId: widget.requestId,
            fields: {
              'status': previousStatus ?? 'pending',
              'cancelled_at': null,
            },
          );
          await _load();
        },
      );
    } catch (_) {
      _showError('Could not cancel this request.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  Future<void> _reopenRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reopen this request?'),
        content: const Text(
            'This resumes the follow-up workflow and schedules a new reminder.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reopen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _requestService.reopenRequest(widget.requestId);
      _showSuccess('Request reopened.');
      await _load();
    } catch (_) {
      _showError('Could not reopen this request.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_request == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request')),
        body: const Center(child: Text('This request could not be found.')),
      );
    }

    final status = _request!['status'] as String? ?? 'pending';
    final title = _request!['title'] as String? ?? 'Request';
    final description = _request!['description'] as String?;
    final dueDate = _parseDate(_request!['due_date']);
    final lastContacted = _parseDate(_request!['last_contacted_at']);
    final nextFollowUp = _parseDate(_request!['next_follow_up_at']);
    final isActive = status == 'pending' || status == 'overdue';
    final canEditItems = status != 'cancelled';
    final dateFormat = DateFormat('MMM d, yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(_clientData['name'] as String? ?? 'Request'),
        actions: [
          IconButton(
            tooltip: 'View history',
            icon: const Icon(Icons.history_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FollowUpHistoryScreen(
                  requestId: widget.requestId,
                  requestTitle: _request!['title'] as String? ?? 'Request',
                ),
              ),
            ),
          ),
          if (isActive)
            IconButton(
              tooltip: 'Cancel request',
              icon: const Icon(Icons.cancel_outlined),
              onPressed: _busy ? null : _cancelRequest,
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusHeader(status: status, title: title),
                if (description != null && description.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(description, style: TextStyle(color: AppColors.inkSoft)),
                ],
                const SizedBox(height: 20),
                _InfoCard(
                  children: [
                    _InfoRow(
                      icon: Icons.person_outline,
                      label: _clientData['name'] as String? ?? 'Unknown client',
                      subtitle: _clientData['email'] as String?,
                    ),
                    if ((_clientData['phone'] as String? ?? '').isNotEmpty)
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: _clientData['phone'] as String,
                      ),
                    _InfoRow(
                      icon: Icons.event_outlined,
                      label:
                      dueDate == null ? 'No due date set' : 'Due ${dateFormat.format(dueDate)}',
                    ),
                    _InfoRow(
                      icon: Icons.history_outlined,
                      label: lastContacted == null
                          ? 'Not contacted yet'
                          : 'Last contacted ${dateFormat.format(lastContacted)}',
                    ),
                    if (isActive)
                      _InfoRow(
                        icon: Icons.notifications_active_outlined,
                        label: nextFollowUp == null
                            ? 'No further follow-ups scheduled'
                            : 'Next follow-up ${dateFormat.format(nextFollowUp)}',
                      ),
                    if (isActive)
                      _InfoRow(
                        icon: Icons.repeat_outlined,
                        label:
                        'Reminder days: ${((_request!['reminder_cadence'] as List?)?.join(', ')) ?? '—'}',
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _requestService.streamRequestItems(widget.requestId),
                  builder: (context, snapshot) {
                    final items = snapshot.data ?? [];
                    final loadingItems = !snapshot.hasData;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Required items',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            if (canEditItems)
                              TextButton.icon(
                                onPressed: _busy ? null : _addItem,
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add item'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (loadingItems)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (items.isEmpty)
                          Text('No items on this request.',
                              style: TextStyle(color: AppColors.inkSoft))
                        else
                          Column(
                            children: items
                                .map((item) => _ItemTile(
                              item: item,
                              busy: _busy,
                              onToggle: () => _toggleItem(item),
                              onDelete: canEditItems && items.length > 1
                                  ? () => _removeItem(item)
                                  : null,
                            ))
                                .toList(),
                          ),
                        const SizedBox(height: 28),
                        if (isActive) ...[
                          SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _busy ? null : () => _openGenerateReminder(items),
                              icon: const Icon(Icons.campaign_outlined),
                              label: const Text('Generate reminder'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _busy ? null : _callClient,
                                  icon: const Icon(Icons.call_outlined),
                                  label: const Text('Call'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _busy ? null : _markContacted,
                                  icon: const Icon(Icons.check_circle_outline),
                                  label: const Text('Mark contacted'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),           // ← new
                          SizedBox(                              // ← new
                            height: 48,                           // ← new
                            child: OutlinedButton.icon(            // ← new
                              onPressed: _busy ? null : _extendDueDate, // ← new
                              icon: const Icon(Icons.event_outlined),   // ← new
                              label: const Text('Extend due date'),     // ← new
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _editCadence,
                              icon: const Icon(Icons.schedule_outlined),
                              label: const Text('Edit reminder schedule'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 48,
                            child: TextButton(
                              onPressed: _busy ? null : _completeRequest,
                              child: const Text('Mark request complete'),
                            ),
                          ),
                          // NEW — replace it with this:
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.sageLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  status == 'complete'
                                      ? Icons.check_circle_outline
                                      : Icons.block_outlined,
                                  color: AppColors.forStatus(status),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    status == 'complete'
                                        ? 'This request is complete.'
                                        : 'This request was cancelled.',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (status == 'cancelled') ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _reopenRequest,
                                icon: const Icon(Icons.refresh_outlined),
                                label: const Text('Reopen request'),
                              ),
                            ),
                          ],
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  final String status;
  final String title;

  const _StatusHeader({required this.status, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style:
            Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.forStatus(status).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            status[0].toUpperCase() + status.substring(1),
            style: TextStyle(
              color: AppColors.forStatus(status),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.paperRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;

  const _InfoRow({required this.icon, required this.label, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.sageDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(subtitle!, style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  const _ItemTile({
    required this.item,
    required this.busy,
    required this.onToggle,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final received = item['status'] == 'received';
    final instructions = item['instructions'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.paperRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line),
      ),
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: received,
        onChanged: busy ? null : (_) => onToggle(),
        title: Text(
          item['name'] as String? ?? '',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: received ? TextDecoration.lineThrough : null,
            color: received ? AppColors.inkSoft : AppColors.ink,
          ),
        ),
        subtitle: instructions != null && instructions.isNotEmpty ? Text(instructions) : null,
        secondary: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              received ? 'Received' : 'Missing',
              style: TextStyle(
                color: AppColors.forStatus(received ? 'complete' : 'pending'),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            if (onDelete != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove item',
                icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.rust),
                onPressed: busy ? null : onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }
}