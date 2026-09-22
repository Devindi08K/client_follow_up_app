import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class GeneratedMessage {
  final String subject;
  final String body;

  GeneratedMessage({required this.subject, required this.body});
}

/// Builds reminder messages and hands them off to the business's own tools
/// (email, WhatsApp, phone). This app never sends anything itself — see
/// TECHNICAL_ARCHITECTURE §21-23 and §25.
class MessageService {
  /// Deterministic template — no external AI call for the MVP
  /// (PROJECT_MASTER_PLAN §14, New_Product_Direction §18).
  GeneratedMessage buildReminder({
    required String clientName,
    required String requestTitle,
    required List<String> missingItemNames,
    DateTime? dueDate,
    bool alreadyContacted = false,
  }) {
    final firstName =
    clientName.trim().isEmpty ? 'there' : clientName.trim().split(' ').first;
    final itemsList = _formatList(missingItemNames);

    final buffer = StringBuffer();
    buffer.write('Hi $firstName,\n\n');

    if (alreadyContacted) {
      buffer.write("Just a quick follow-up — we're still waiting on ");
    } else {
      buffer.write("Just a quick reminder that we're still waiting for ");
    }
    buffer.write('$itemsList for "$requestTitle".\n\n');

    if (dueDate != null) {
      buffer.write(
          'It would help a lot if we could have this by ${_formatDate(dueDate)}.\n\n');
    }

    buffer.write('Please send them over when you get a chance.\n\nThanks!');

    final subject = missingItemNames.length == 1
        ? 'Reminder: ${missingItemNames.first}'
        : 'Reminder: a few outstanding items for "$requestTitle"';

    return GeneratedMessage(subject: subject, body: buffer.toString());
  }

  String _formatList(List<String> items) {
    if (items.isEmpty) return 'a few things';
    if (items.length == 1) return items.first;
    if (items.length == 2) return '${items[0]} and ${items[1]}';
    final head = items.sublist(0, items.length - 1).join(', ');
    return '$head, and ${items.last}';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  Future<void> copyToClipboard(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  /// Opens the device's email app with a prefilled recipient/subject/body.
  /// Returns false if no email app could be launched.
  Future<bool> openEmail({
    required String recipient,
    required String subject,
    required String body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: recipient,
      query: _encodeQuery({'subject': subject, 'body': body}),
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Opens WhatsApp with a prefilled message. [phone] is the raw number as
  /// stored on the client (may include spaces/dashes/plus sign).
  Future<bool> openWhatsApp({required String phone, required String message}) async {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return false;

    final uri =
    Uri.parse('https://wa.me/$digitsOnly?text=${Uri.encodeComponent(message)}');
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<bool> openDialer(String phone) async {
    if (phone.trim().isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: phone.trim());
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}