import 'package:flutter/material.dart';

import '../../../models/client.dart';
import '../../../models/request_item_draft.dart';
import '../../../services/request_service.dart';
import '../../../theme/app_theme.dart';
import 'step1_select_client.dart';
import 'step2_request_details.dart';
import 'step3_add_items.dart';
import 'step4_reminder_schedule.dart';
import 'step5_review_send.dart';

class NewRequestWizardScreen extends StatefulWidget {
  const NewRequestWizardScreen({super.key});

  @override
  State<NewRequestWizardScreen> createState() => _NewRequestWizardScreenState();
}

class _NewRequestWizardScreenState extends State<NewRequestWizardScreen> {
  final _pageController = PageController();
  final _requestService = RequestService();

  int _currentStep = 0;
  ClientModel? _selectedClient;

  String _title = '';
  String _description = '';
  DateTime? _dueDate;

  final List<RequestItemDraft> _items = [];

  List<int> _cadence = List<int>.from(RequestService.defaultCadence);

  bool _sending = false;

  static const _stepTitles = ['Client', 'Details', 'Items', 'Reminders', 'Review'];

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not create request: $e'),
          duration: const Duration(seconds: 6)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('New request · ${_stepTitles[_currentStep]}')),
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
                          ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.paperRaised))
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