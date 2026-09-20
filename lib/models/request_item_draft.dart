// lib/models/request_item_draft.dart
class RequestItemDraft {
  String name;
  String instructions;

  RequestItemDraft({
    required this.name,
    this.instructions = '',
  });
}