import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class Step4ReminderSchedule extends StatefulWidget {
  final List<int> cadence;
  final ValueChanged<List<int>> onChanged;

  const Step4ReminderSchedule({super.key, required this.cadence, required this.onChanged});

  @override
  State<Step4ReminderSchedule> createState() => _Step4ReminderScheduleState();
}

class _Step4ReminderScheduleState extends State<Step4ReminderSchedule> {
  static const List<List<int>> _presets = [
    [1, 3, 7],
    [3, 7, 14],
    [7, 14, 30],
  ];

  late List<int> _cadence;
  bool get _isCustomSelected => !_presets.any((p) => _sameList(p, _cadence));

  @override
  void initState() {
    super.initState();
    _cadence = List<int>.from(widget.cadence);
  }

  bool _sameList(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _selectPreset(List<int> preset) {
    setState(() => _cadence = List<int>.from(preset));
    widget.onChanged(_cadence);
  }

  Future<void> _editCustom() async {
    final controller =
    TextEditingController(text: _cadence.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom schedule'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            labelText: 'Days after creation, comma-separated',
            hintText: 'e.g. 2, 5, 10',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
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

    setState(() => _cadence = parsed);
    widget.onChanged(_cadence);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('When should we remind you to follow up?',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            'These are reminders for you — the business. We never message the client automatically.',
            style: TextStyle(color: context.palette.textSecondary),
          ),
          const SizedBox(height: 20),
          ..._presets.map((preset) => _PresetTile(
            days: preset,
            selected: _sameList(preset, _cadence),
            onTap: () => _selectPreset(preset),
          )),
          _PresetTile(
            days: _isCustomSelected ? _cadence : null,
            selected: _isCustomSelected,
            label: 'Custom',
            onTap: _editCustom,
          ),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final List<int>? days;
  final bool selected;
  final String? label;
  final VoidCallback onTap;

  const _PresetTile({required this.days, required this.selected, required this.onTap, this.label});

  @override
  Widget build(BuildContext context) {
    final title = label ?? 'Day ${days!.join(', ')}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        tileColor: selected ? context.palette.surface2 : context.palette.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: context.palette.border),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: days != null
            ? Text('Follow-up reminders on day${days!.length > 1 ? 's' : ''} ${days!.join(', ')}')
            : const Text('Set your own days'),
        trailing: selected ? const Icon(Icons.check_circle, color: AppStatusColors.forest) : null,
        onTap: onTap,
      ),
    );
  }
}