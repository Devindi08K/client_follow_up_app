import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/request_template.dart';
import '../models/request_item_draft.dart';
import 'plan_limits.dart';
import 'purchase_service.dart';

class TemplateService {
  final SupabaseClient _client = Supabase.instance.client;

  Stream<List<RequestTemplate>> streamTemplates() {
    final uid = _client.auth.currentUser!.id;
    return _client
        .from('request_templates')
        .stream(primaryKey: ['id'])
        .eq('business_id', uid)
        .order('name')
        .map((rows) => rows.map(RequestTemplate.fromMap).toList());
  }

  Future<void> createTemplate({
    required String name,
    required String title,
    String description = '',
    required List<RequestItemDraft> items,
    required List<int> cadence,
  }) async {
    final uid = _client.auth.currentUser!.id;
    if (name.trim().isEmpty) throw Exception('Template name is required.');
    if (items.isEmpty) throw Exception('Add at least one item.');

    final isPro = await PurchaseService().isPro();
    if (!isPro) {
      final existing = await _client.from('request_templates').select('id').eq('business_id', uid);
      if (existing.length >= PlanLimits.freeMaxTemplates) {
        throw FreeTierLimitException(
          'Free plan is limited to ${PlanLimits.freeMaxTemplates} saved templates. '
              'Delete one or upgrade to Pro to save more.',
          'templates',
        );
      }
    }

    await _client.from('request_templates').insert({
      'business_id': uid,
      'name': name.trim(),
      'title': title.trim(),
      'description': description.trim().isEmpty ? null : description.trim(),
      'items': items
          .map((i) => {'name': i.name.trim(), 'instructions': i.instructions.trim()})
          .toList(),
      'reminder_cadence': cadence,
    });
  }

  Future<void> deleteTemplate(String id) async {
    await _client.from('request_templates').delete().eq('id', id);
  }
}