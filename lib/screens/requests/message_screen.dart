import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/business_service.dart';

import '../../services/message_service.dart';
import '../../services/request_service.dart';
import '../../theme/app_theme.dart';

/// B7 — Reminder / Message screen. The message is generated for the
/// business to review; this screen never sends anything itself
/// (TECHNICAL_ARCHITECTURE §21-23).
class MessageScreen extends StatefulWidget {
  final String requestId;
  final String clientName;
  final String clientEmail;
  final String clientPhone;
  final String requestTitle;
  final List<String> missingItemNames;
  final DateTime? dueDate;
  final bool alreadyContacted;

  const MessageScreen({
    super.key,
    required this.requestId,
    required this.clientName,
    required this.clientEmail,
    required this.clientPhone,
    required this.requestTitle,
    required this.missingItemNames,
    this.dueDate,
    this.alreadyContacted = false,
  });

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> {
  final _messageService = MessageService();
  final _requestService = RequestService();

  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;

  bool _busy = false;
  bool _didAnything = false;

  @override
  void initState() {
    super.initState();
    _subjectController = TextEditingController();
    _bodyController = TextEditingController();
    _loadMessage();
    _requestService.logReminderGenerated(widget.requestId);
  }

  Future<void> _loadMessage() async {
    String businessName = '';
    String? bodyTemplate;
    String? subjectTemplate;
    try {
      final profile = await BusinessService().getBusinessProfile();
      businessName = profile?['name'] as String? ?? '';
      bodyTemplate = profile?['message_template'] as String?;
      subjectTemplate = profile?['subject_template'] as String?;
    } catch (_) {
      // Fall back to the default template if the profile can't be loaded.
    }

    final generated = _messageService.buildReminder(
      clientName: widget.clientName,
      requestTitle: widget.requestTitle,
      missingItemNames: widget.missingItemNames,
      dueDate: widget.dueDate,
      alreadyContacted: widget.alreadyContacted,
      businessName: businessName,
      customBodyTemplate: bodyTemplate,
      customSubjectTemplate: subjectTemplate,
    );

    if (!mounted) return;
    setState(() {
      _subjectController.text = generated.subject;
      _bodyController.text = generated.body;
    });
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _markContacted(String channel) async {
    setState(() => _busy = true);
    try {
      await _requestService.markContacted(requestId: widget.requestId, channel: channel);
      _didAnything = true;
    } catch (_) {
      // Non-fatal — the message action itself already succeeded.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    await _messageService.copyToClipboard('${_subjectController.text}\n\n${_bodyController.text}');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied.')),
    );
  }

  Future<void> _share() async {
    await SharePlus.instance.share(
      ShareParams(text: '${_subjectController.text}\n\n${_bodyController.text}'),
    );
  }

  Future<void> _openEmail() async {
    if (widget.clientEmail.isEmpty) {
      _showError('This client has no email address saved.');
      return;
    }
    final opened = await _messageService.openEmail(
      recipient: widget.clientEmail,
      subject: _subjectController.text,
      body: _bodyController.text,
    );
    if (opened) {
      await _markContacted('email');
    } else if (mounted) {
      _showError('No email application is available on this device.');
    }
  }

  Future<void> _openWhatsApp() async {
    if (widget.clientPhone.isEmpty) {
      _showError('This client has no phone number saved.');
      return;
    }
    final opened = await _messageService.openWhatsApp(
      phone: widget.clientPhone,
      message: _bodyController.text,
    );
    if (opened) {
      await _markContacted('whatsapp');
    } else if (mounted) {
      _showError('WhatsApp is not available on this device.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor:AppStatusColors.rust),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminder message'),
        leading: BackButton(onPressed: () => Navigator.pop(context, _didAnything)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Missing items',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.missingItemNames
                    .map((name) => Chip(
                  label: Text(name),
                  backgroundColor: context.palette.surface2,
                  side: BorderSide.none,
                ))
                    .toList(),
              ),
              const SizedBox(height: 24),
              Text('Suggested subject',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(controller: _subjectController),
              const SizedBox(height: 20),
              Text('Suggested message',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _bodyController,
                minLines: 6,
                maxLines: 14,
              ),
              const SizedBox(height: 24),
              if (widget.clientEmail.isEmpty && widget.clientPhone.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: context.palette.surface2,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: context.palette.textSecondary),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'No email or phone on file. Copy the message, share it another way, or mark them contacted manually.',
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _copy,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy message'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _share,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share via...'),
                ),
              ),
              if (widget.clientEmail.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _openEmail,
                    icon: const Icon(Icons.email_outlined),
                    label: const Text('Open email'),
                  ),
                ),
              ],
              if (widget.clientPhone.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _openWhatsApp,
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('Open WhatsApp'),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: TextButton(
                  onPressed: _busy
                      ? null
                      : () async {
                    final navigator = Navigator.of(context);
                    await _markContacted('manual');
                    navigator.pop(true);
                  },
                  child: const Text('Mark contacted without sending'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}