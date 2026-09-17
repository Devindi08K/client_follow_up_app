// lib/screens/requests/new_request_wizard/new_request_wizard_screen.dart
import 'package:flutter/material.dart';

import '../../../models/client.dart';
import '../../../models/request_item_draft.dart';
import '../../../services/request_service.dart';
import '../../../theme/app_theme.dart';
import 'step1_select_client.dart';
import 'step2_add_items.dart';
import 'step3_review_send.dart';

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
  final List<RequestItemDraft> _items = [];
  bool _sending = false;

  bool get _canGoNext {
    switch (_currentStep) {
      case 0:
        return _selectedClient != null;
      case 1:
        return _items.isNotEmpty &&
            _items.every((item) => item.name.trim().isNotEmpty);
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
    debugPrint('🔵 _sendRequest called, client=${_selectedClient?.id}, items=${_items.length}');
    if (_selectedClient == null) return;
    setState(() => _sending = true);

    try {
      await _requestService.createRequest(
        clientId: _selectedClient!.id,
        items: _items,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('❌ createRequest failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not create request: $e'), duration: const Duration(seconds: 6)));
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
    const stepTitles = ['Client', 'Items', 'Review'];

    return Scaffold(
      appBar: AppBar(title: Text('New request · ${stepTitles[_currentStep]}')),
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
                Step2AddItems(items: _items, onChanged: () => setState(() {})),
                if (_selectedClient != null)
                  Step3ReviewSend(client: _selectedClient!, items: _items)
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
                        debugPrint('🟢 Button tapped, currentStep=$_currentStep, canGoNext=$_canGoNext');
                        if (_currentStep < 2) {
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
                          : Text(_currentStep < 2 ? 'Next' : 'Create & send'),
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