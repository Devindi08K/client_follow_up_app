import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/client.dart';
import '../../../models/request_item_draft.dart';
import '../../../services/business_service.dart';
import '../../../services/request_service.dart';
import '../../../theme/app_theme.dart';
import 'step1_select_client.dart';
import 'step2_request_details.dart';
import 'step3_add_items.dart';
import 'step4_reminder_schedule.dart';
import 'step5_review_send.dart';
import '../../../models/request_template.dart';
import '../../../services/template_service.dart';
import '../../../widgets/upgrade_prompt.dart';

class NewRequestWizardScreen extends StatefulWidget {
  final ClientModel? initialClient;

  const NewRequestWizardScreen({super.key, this.initialClient});

  @override
  State<NewRequestWizardScreen> createState() => _NewRequestWizardScreenState();
}

class _NewRequestWizardScreenState extends State<NewRequestWizardScreen> {
  late final _pageController = PageController(
    initialPage: widget.initialClient != null ? 1 : 0,
  );
  final _requestService = RequestService();

  late int _currentStep = widget.initialClient != null ? 1 : 0;
  late ClientModel? _selectedClient = widget.initialClient;

  String _title = '';
  String _description = '';
  DateTime? _dueDate;

  final List<RequestItemDraft> _items = [];

  List<int> _cadence = List<int>.from(RequestService.defaultCadence);

  bool _sending = false;

  static const _stepTitles = ['Client', 'Details', 'Items', 'Reminders', 'Review'];

  @override
  void initState() {
    super.initState();
    _loadDefaultCadence();
  }

  Future<void> _loadDefaultCadence() async {
    try {
      final profile = await BusinessService().getBusinessProfile();
      final raw = profile?['default_reminder_cadence'] as List?;
      if (raw != null && raw.isNotEmpty && mounted) {
        setState(() => _cadence = raw.map((e) => e as int).toList()..sort());
      }
    } catch (_) {
      // Fall back silently to the static default — non-critical.
    }
  }

  bool get _canGoNext {
    switch (_currentStep) {
      case 0:
        return _selectedClient != null;
      case 1:
        return _title.trim().isNotEmpty;
      case 2:
        return _items.isNotEmpty &&
            _items.every((item) => item.name.trim().isNotEmpty);
      case 3:
        return _cadence.isNotEmpty;
      default:
        return true;
    }
  }

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(step,
        duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
  }

  Future<void> _sendRequest() async {
    if (_selectedClient == null) return;
    setState(() => _sending = true);

    try {
      final duplicates = await _requestService.findPossibleDuplicateRequests(
        clientId: _selectedClient!.id,
        title: _title,
      );

      if (duplicates.isNotEmpty) {
        setState(() => _sending = false);
        if (!mounted) return;
        final proceed = await _confirmDuplicateRequest(duplicates);
        if (proceed != true) return;
        if (!mounted) return;
        setState(() => _sending = true);
      }

      await _requestService.createRequest(
        clientId: _selectedClient!.id,
        items: _items,
        title: _title,
        description: _description,
        dueDate: _dueDate,
        reminderCadence: _cadence,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      await showUpgradePromptIfLimitReached(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _applyTemplate(RequestTemplate t) async {
    setState(() {
      _title = t.title;
      _description = t.description;
      _items
        ..clear()
        ..addAll(t.items.map((i) => RequestItemDraft(name: i.name, instructions: i.instructions)));
      _cadence = List<int>.from(t.reminderCadence);
    });
  }
  Future<void> _saveAsTemplate() async {
    final nameController = TextEditingController(text: _title);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save as template'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Template name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true || nameController.text.trim().isEmpty) return;

    try {
      await TemplateService().createTemplate(
        name: nameController.text,
        title: _title,
        description: _description,
        items: _items,
        cadence: _cadence,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Template saved.')));
    } catch (e) {
      if (!mounted) return;
      await showUpgradePromptIfLimitReached(context, e);
    }
  }

  Future<void> _pickTemplate() async {
    final templates = await TemplateService().streamTemplates().first;
    if (!mounted) return;
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No templates yet. Save one from Settings > Templates.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<RequestTemplate>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: templates
              .map((t) => ListTile(title: Text(t.name), subtitle: Text(t.title), onTap: () => Navigator.pop(context, t)))
              .toList(),
        ),
      ),
    );
    if (picked != null) _applyTemplate(picked);
  }
  Future<bool?> _confirmDuplicateRequest(List<Map<String, dynamic>> duplicates) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Possible duplicate request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_selectedClient!.name} already has an active request with this title:',
            ),
            const SizedBox(height: 12),
            ...duplicates.take(3).map((r) {
              final status = r['status'] as String? ?? 'pending';
              final createdAt = DateTime.tryParse(r['created_at'] as String? ?? '');
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• ${r['title']} '
                      '(${status[0].toUpperCase()}${status.substring(1)}'
                      '${createdAt != null ? ' · created ${dateFormat.format(createdAt)}' : ''})',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create anyway'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('New request · ${_stepTitles[_currentStep]}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'Use template',
            onPressed: _pickTemplate,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                Step1SelectClient(
                  selectedClient: _selectedClient,
                  onClientSelected: (client) =>
                      setState(() => _selectedClient = client),
                ),
                Step2RequestDetails(
                  title: _title,
                  description: _description,
                  dueDate: _dueDate,
                  onChanged: (title, description, dueDate) {
                    setState(() {
                      _title = title;
                      _description = description;
                      _dueDate = dueDate;
                    });
                  },
                ),
                Step3AddItems(items: _items, onChanged: () => setState(() {})),
                Step4ReminderSchedule(
                  cadence: _cadence,
                  onChanged: (cadence) => setState(() => _cadence = cadence),
                ),
                if (_selectedClient != null)
                  Step5ReviewSend(
                    client: _selectedClient!,
                    title: _title,
                    description: _description,
                    dueDate: _dueDate,
                    items: _items,
                    cadence: _cadence,
                    onSaveAsTemplate: _saveAsTemplate,
                  )
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                        _sending ? null : () => _goToStep(_currentStep - 1),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: !_canGoNext || _sending
                          ? null
                          : () {
                        if (_currentStep < 4) {
                          _goToStep(_currentStep + 1);
                        } else {
                          _sendRequest();
                        }
                      },
                      child: _sending
                          ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: context.palette.surface1))
                          : Text(_currentStep < 4 ? 'Next' : 'Create request'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}