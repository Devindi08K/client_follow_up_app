import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';

class Step2RequestDetails extends StatefulWidget {
  final String title;
  final String description;
  final DateTime? dueDate;
  final void Function(String title, String description, DateTime? dueDate) onChanged;

  const Step2RequestDetails({
    super.key,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.onChanged,
  });

  @override
  State<Step2RequestDetails> createState() => _Step2RequestDetailsState();
}

class _Step2RequestDetailsState extends State<Step2RequestDetails> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.title);
    _descriptionController = TextEditingController(text: widget.description);
    _dueDate = widget.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _emit() {
    widget.onChanged(_titleController.text, _descriptionController.text, _dueDate);
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
      _emit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What is this request about?',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
                labelText: 'Request title',
                hintText: 'e.g. Monthly Accounting Documents'),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
                labelText: 'Description (optional)',
                alignLabelWithHint: true),
            onChanged: (_) => _emit(),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDueDate,
            icon: const Icon(Icons.event_outlined),
            label: Text(_dueDate == null
                ? 'Set due date (optional)'
                : 'Due ${dateFormat.format(_dueDate!)}'),
          ),
          if (_dueDate != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () {
                  setState(() => _dueDate = null);
                  _emit();
                },
                child: const Text('Clear due date'),
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.palette.surface2,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              "The title is what you and the client will see on every reminder. Keep it specific.",
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}