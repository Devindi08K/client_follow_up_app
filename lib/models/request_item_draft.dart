// lib/models/request_item_draft.dart
class RequestItemDraft {
  String name;
  String instructions;
  String type; // 'file' or 'text'

  RequestItemDraft({
    required this.name,
    this.instructions = '',
    this.type = 'file',
  });
}