import 'package:flutter/material.dart';
import '../../models/request_template.dart';
import '../../services/template_service.dart';
import '../../theme/app_theme.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = TemplateService();
    return Scaffold(
      appBar: AppBar(title: const Text('Request templates')),
      body: StreamBuilder<List<RequestTemplate>>(
        stream: service.streamTemplates(),
        builder: (context, snapshot) {
          final templates = snapshot.data ?? [];
          if (templates.isEmpty) {
            return Center(
              child: Text('No templates yet. Create one from the new request wizard.',
                  style: TextStyle(color: context.palette.textSecondary)),
            );
          }
          return ListView.builder(
            itemCount: templates.length,
            itemBuilder: (context, i) {
              final t = templates[i];
              return ListTile(
                title: Text(t.name),
                subtitle: Text('${t.title} · ${t.items.length} items'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppStatusColors.rust),
                  onPressed: () => service.deleteTemplate(t.id),
                ),
              );
            },
          );
        },
      ),
    );
  }
}