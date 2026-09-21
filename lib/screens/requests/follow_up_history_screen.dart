import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/request_service.dart';
import '../../theme/app_theme.dart';

class FollowUpHistoryScreen extends StatelessWidget {
  final String requestId;
  final String requestTitle;

  const FollowUpHistoryScreen({
    super.key,
    required this.requestId,
    required this.requestTitle,
  });

  String _actionLabel(String action) {
    switch (action) {
      case 'generated':
        return 'Reminder generated';
      case 'contacted':
        return 'Contacted';
      case 'marked_received':
        return 'Item marked received';
      case 'reopened':
        return 'Reopened';   // was 'Item reopened' — now covers both item- and request-level
      case 'due_date_extended':
        return 'Due date extended';
      default:
        return action;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'generated':
        return Icons.campaign_outlined;
      case 'contacted':
        return Icons.check_circle_outline;
      case 'marked_received':
        return Icons.inventory_2_outlined;
      case 'reopened':
        return Icons.refresh_outlined;
      case 'due_date_extended':
        return Icons.event_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  String? _channelLabel(String? channel) {
    switch (channel) {
      case 'email':
        return 'Email';
      case 'whatsapp':
        return 'WhatsApp';
      case 'phone':
        return 'Phone';
      case 'manual':
        return 'Manual';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, yyyy · h:mm a');

    return Scaffold(
      appBar: AppBar(title: Text('History · $requestTitle')),
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: RequestService().streamFollowUpHistory(requestId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final entries = snapshot.data!;
            if (entries.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No activity recorded yet.',
                    style: TextStyle(color: AppColors.inkSoft),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final entry = entries[index];
                final action = entry['action'] as String? ?? '';
                final channel = _channelLabel(entry['channel'] as String?);
                final notes = entry['notes'] as String?;
                final createdAt = DateTime.tryParse(entry['created_at'] as String? ?? '');

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.paperRaised,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(_actionIcon(action), color: AppColors.sageDeep, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(_actionLabel(action),
                                    style: const TextStyle(fontWeight: FontWeight.w700)),
                                if (channel != null) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.sageLight,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(channel,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              createdAt == null ? '' : dateFormat.format(createdAt),
                              style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
                            ),
                            if (notes != null && notes.trim().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(notes),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}