import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/business_service.dart';
import '../../services/request_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _businessService = BusinessService();

  bool _loading = true;
  bool _busy = false;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _email = '';
  String _plan = 'free';

  static const List<List<int>> _presets = [
    [1, 3, 7],
    [3, 7, 14],
    [7, 14, 30],
  ];
  List<int> _cadence = List<int>.from(RequestService.defaultCadence);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profile = await _businessService.getBusinessProfile();
      if (!mounted) return;
      final rawCadence = profile?['default_reminder_cadence'] as List?;
      setState(() {
        _nameController.text = profile?['name'] as String? ?? '';
        _phoneController.text = profile?['phone'] as String? ?? '';
        _email = profile?['email'] as String? ?? '';
        _plan = profile?['plan'] as String? ?? 'free';
        _cadence = (rawCadence != null && rawCadence.isNotEmpty)
            ? (rawCadence.map((e) => e as int).toList()..sort())
            : List<int>.from(RequestService.defaultCadence);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Could not load your business profile.');
    }
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

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      _showError('Business name can\'t be empty.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _businessService.updateBusinessProfile(
        name: _nameController.text,
        phone: _phoneController.text,
      );
      _showSuccess('Business profile updated.');
    } catch (_) {
      _showError('Could not save your profile.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool _sameList(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _selectPreset(List<int> preset) async {
    setState(() => _cadence = List<int>.from(preset));
    await _saveCadence();
  }

  Future<void> _editCustomCadence() async {
    final controller = TextEditingController(text: _cadence.join(', '));
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom schedule'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Days after creation, comma-separated',
            hintText: 'e.g. 2, 5, 10',
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

    setState(() => _cadence = parsed);
    await _saveCadence();
  }

  Future<void> _saveCadence() async {
    setState(() => _busy = true);
    try {
      await _businessService.updateDefaultReminderCadence(_cadence);
      _showSuccess('Default reminder schedule updated.');
    } catch (_) {
      _showError('Could not save the reminder schedule.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isCustom = !_presets.any((p) => _sameList(p, _cadence));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Business profile',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Business name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _email,
              enabled: false,
              decoration: const InputDecoration(labelText: 'Email (sign-in address)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Business phone (optional)'),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _busy ? null : _saveProfile,
              child: const Text('Save profile'),
            ),
            const SizedBox(height: 32),
            Text('Appearance',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {ThemeService.instance.mode},
              onSelectionChanged: (selected) => ThemeService.instance.setMode(selected.first),
            ),
            const SizedBox(height: 32),
            Text('Default reminder schedule',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'New requests start with this schedule. You can still override it per request.',
              style: TextStyle(color: context.palette.textSecondary),
            ),
            const SizedBox(height: 14),
            ..._presets.map((preset) => _ScheduleTile(
              title: 'Day ${preset.join(', ')}',
              selected: _sameList(preset, _cadence),
              onTap: _busy ? null : () => _selectPreset(preset),
            )),
            _ScheduleTile(
              title: isCustom ? 'Custom (Day ${_cadence.join(', ')})' : 'Custom',
              selected: isCustom,
              onTap: _busy ? null : _editCustomCadence,
            ),
            const SizedBox(height: 32),
            Text('Subscription',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.palette.surface1,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: context.palette.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium_outlined, color: context.palette.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Current plan: ${_plan[0].toUpperCase()}${_plan.substring(1)}'),
                  ),
                  OutlinedButton(
                    onPressed: null, // subscription wiring deferred — see master plan §30/§19
                    child: const Text('Manage'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout_outlined),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback? onTap;

  const _ScheduleTile({required this.title, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        tileColor: selected ? context.palette.surface2 : context.palette.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: context.palette.border),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: selected ? const Icon(Icons.check_circle, color: AppStatusColors.forest) : null,
        onTap: onTap,
      ),
    );
  }
}