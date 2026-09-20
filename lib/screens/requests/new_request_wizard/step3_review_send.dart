// lib/screens/requests/new_request_wizard/step3_review_send.dart
import 'package:flutter/material.dart';

import '../../../models/client.dart';
import '../../../models/request_item_draft.dart';
import '../../../theme/app_theme.dart';

class Step3ReviewSend extends StatelessWidget {
  final ClientModel client;
  final List<RequestItemDraft> items;

  const Step3ReviewSend({super.key, required this.client, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Review & send',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Text('Client', style: TextStyle(color: AppColors.inkSoft)),
          Text(client.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(client.email),
          const SizedBox(height: 20),
          Text('Items requested (${items.length})',
              style: TextStyle(color: AppColors.inkSoft)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  tileColor: AppColors.paperRaised,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: const BorderSide(color: AppColors.line),
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
              color: AppColors.sageLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Reminders will be sent on day 1, 3, and 7 if items are still missing.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}