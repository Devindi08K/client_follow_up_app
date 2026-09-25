// lib/screens/requests/new_request_wizard/step5_review_send.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/client.dart';
import '../../../models/request_item_draft.dart';
import '../../../theme/app_theme.dart';

class Step5ReviewSend extends StatelessWidget {
  final ClientModel client;
  final String title;
  final String description;
  final DateTime? dueDate;
  final List<RequestItemDraft> items;
  final List<int> cadence;
  final VoidCallback onSaveAsTemplate;

  const Step5ReviewSend({
    super.key,
    required this.client,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.items,
    required this.cadence,
    required this.onSaveAsTemplate,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Review & create',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Text('Client', style: TextStyle(color: context.palette.textSecondary)),
          Text(client.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(client.email),
          const SizedBox(height: 16),
          Text('Request', style: TextStyle(color: context.palette.textSecondary)),
          Text(title.trim().isEmpty ? 'Request' : title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (description.trim().isNotEmpty) Text(description),
          if (dueDate != null) ...[
            const SizedBox(height: 4),
            Text('Due ${dateFormat.format(dueDate!)}'),
          ],
          const SizedBox(height: 20),
          Text('Items requested (${items.length})',
              style: TextStyle(color: context.palette.textSecondary)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  tileColor: context.palette.surface1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(color: context.palette.border),
                  ),
                  title: Text(item.name),
                  subtitle:
                  item.instructions.isNotEmpty ? Text(item.instructions) : null,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.palette.surface2,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Reminders will be due on day${cadence.length > 1 ? 's' : ''} ${cadence.join(', ')} if items are still missing.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onSaveAsTemplate,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('Save as template'),
          ),
        ],
      ),
    );
  }
}