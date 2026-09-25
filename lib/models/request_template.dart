import 'request_item_draft.dart';

class RequestTemplate {
  final String id;
  final String name;
  final String title;
  final String description;
  final List<RequestItemDraft> items;
  final List<int> reminderCadence;

  RequestTemplate({
    required this.id,
    required this.name,
    required this.title,
    this.description = '',
    required this.items,
    required this.reminderCadence,
  });

  factory RequestTemplate.fromMap(Map<String, dynamic> row) {
    final itemsRaw = (row['items'] as List?) ?? [];
    return RequestTemplate(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      title: row['title'] as String? ?? '',
      description: row['description'] as String? ?? '',
      items: itemsRaw
          .map((e) => RequestItemDraft(
        name: (e as Map)['name'] as String? ?? '',
        instructions: e['instructions'] as String? ?? '',
      ))
          .toList(),
      reminderCadence:
      ((row['reminder_cadence'] as List?) ?? [1, 3, 7]).map((e) => e as int).toList(),
    );
  }
}