import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/auth_service.dart';
import '../../services/business_service.dart';
import '../../services/request_service.dart';
import '../../services/theme_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/phone_input_field.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/account_service.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _businessService = BusinessService();
  final _accountService = AccountService();

  bool _loading = true;
  bool _busy = false;
  String _appVersion = '';

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _messageTemplateController = TextEditingController();
  final _subjectTemplateController = TextEditingController();
  String _email = '';
  String _plan = 'free';
  String _country = 'Sri Lanka';
  String _timezone = 'Asia/Colombo';
  String _language = 'en';

  static const List<String> _countries = [
    'Sri Lanka',
    'India',
    'United States',
    'United Kingdom',
    'Australia',
    'Canada',
    'Singapore',
    'United Arab Emirates',
    'Other',
  ];

  static const List<String> _timezones = [
    'Asia/Colombo',
    'Asia/Kolkata',
    'Asia/Dubai',
    'Asia/Singapore',
    'Europe/London',
    'America/New_York',
    'America/Los_Angeles',
    'Australia/Sydney',
    'UTC',
  ];

  static const Map<String, String> _languages = {
    'en': 'English',
  };

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
    _messageTemplateController.dispose();
    _subjectTemplateController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
      final profile = await _businessService.getBusinessProfile();
      if (!mounted) return;
      final rawCadence = profile?['default_reminder_cadence'] as List?;
      setState(() {
        _nameController.text = profile?['name'] as String? ?? '';
        _phoneController.text = profile?['phone'] as String? ?? '';
        _email = profile?['email'] as String? ?? '';
        _plan = profile?['plan'] as String? ?? 'free';
        _country = profile?['country'] as String? ?? 'Sri Lanka';
        _timezone = profile?['timezone'] as String? ?? 'Asia/Colombo';
        _language = profile?['language'] as String? ?? 'en';
        _messageTemplateController.text = profile?['message_template'] as String? ?? '';
        _subjectTemplateController.text = profile?['subject_template'] as String? ?? '';
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
  Future<void> _saveTemplates() async {
    setState(() => _busy = true);
    try {
      await _businessService.updateMessageTemplates(
        bodyTemplate: _messageTemplateController.text,
        subjectTemplate: _subjectTemplateController.text,
      );
      _showSuccess('Message templates updated.');
    } catch (_) {
      _showError('Could not save message templates.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveLocale() async {
    setState(() => _busy = true);
    try {
      await _businessService.updateBusinessLocale(
        country: _country,
        timezone: _timezone,
        language: _language,
      );
      _showSuccess('Region settings updated.');
    } catch (_) {
      _showError('Could not save region settings.');
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
  Future<void> _exportData() async {
    setState(() => _busy = true);
    try {
      final text = await _accountService.exportDataAsText();
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      _showError('Could not export your data. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
            'This submits a request to permanently delete your business account and '
                'all associated clients and requests. We\'ll process this within a few '
                'business days and email you to confirm. This can\'t be undone once processed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Request deletion', style: TextStyle(color: AppStatusColors.rust)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await _accountService.requestAccountDeletion();
      if (!mounted) return;
      _showSuccess('Deletion request submitted. We\'ll email you once it\'s processed.');
    } catch (_) {
      _showError('Could not submit your request. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
            PhoneInputField(
              initialValue: _phoneController.text,
              onChanged: (value) => _phoneController.text = value,
              labelText: 'Business phone (optional)',
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _busy ? null : _saveProfile,
              child: const Text('Save profile'),
            ),
            const SizedBox(height: 32),
            Text('Region & language',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _country,
              decoration: const InputDecoration(labelText: 'Country'),
              items: _countries
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: _busy ? null : (v) => setState(() => _country = v ?? _country),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _timezone,
              decoration: const InputDecoration(labelText: 'Timezone'),
              items: _timezones
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: _busy ? null : (v) => setState(() => _timezone = v ?? _timezone),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: const InputDecoration(labelText: 'Language'),
              items: _languages.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: _busy ? null : (v) => setState(() => _language = v ?? _language),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _busy ? null : _saveLocale,
              child: const Text('Save region settings'),
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
            Text('Message templates',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Leave blank to use the default wording. Placeholders: {client_name}, {request_name}, {missing_items}, {due_date}, {business_name}.',
              style: TextStyle(color: context.palette.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _subjectTemplateController,
              decoration: const InputDecoration(labelText: 'Subject template (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageTemplateController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Message template (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _busy ? null : _saveTemplates,
              child: const Text('Save templates'),
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
            Text('Privacy & data',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
              icon: const Icon(Icons.privacy_tip_outlined),
              label: const Text('Privacy policy'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _exportData,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export my data'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _requestDeletion,
              icon: const Icon(Icons.delete_forever_outlined, color: AppStatusColors.rust),
              label: const Text('Delete account', style: TextStyle(color: AppStatusColors.rust)),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout_outlined),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                _appVersion.isEmpty ? '' : 'Version $_appVersion',
                style: TextStyle(color: context.palette.textSecondary, fontSize: 12),
              ),
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