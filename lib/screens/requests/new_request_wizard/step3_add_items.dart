// lib/screens/requests/new_request_wizard/step3_add_items.dart
import 'package:flutter/material.dart';

import '../../../models/request_item_draft.dart';
import '../../../theme/app_theme.dart';

class Step3AddItems extends StatefulWidget {
  final List<RequestItemDraft> items;
  final VoidCallback onChanged;

  const Step3AddItems({super.key, required this.items, required this.onChanged});

  @override
  State<Step3AddItems> createState() => _Step3AddItemsState();
}

class _Step3AddItemsState extends State<Step3AddItems> {
  void _addItem() {
    setState(() => widget.items.add(RequestItemDraft(name: '')));
    widget.onChanged();
  }

  void _removeItem(int index) {
    setState(() => widget.items.removeAt(index));
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('What do you need from them?',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Expanded(
            child: widget.items.isEmpty
                ? Center(
                child: Text('Add at least one item below.',
                    style: TextStyle(color: context.palette.textSecondary)))
                : ListView.separated(
              itemCount: widget.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = widget.items[index];

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.palette.surface1,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: item.name,
                              decoration: const InputDecoration(
                                  labelText: 'Item name', isDense: true),
                              onChanged: (v) {
                                item.name = v;
                                widget.onChanged();
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppStatusColors.rust),
                            onPressed: () => _removeItem(index),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: item.instructions,
                        decoration: const InputDecoration(
                            labelText: 'Instructions (optional)',
                            isDense: true),
                        onChanged: (v) {
                          item.instructions = v;
                          widget.onChanged();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
            label: const Text('Add item'),
          ),
        ],
      ),
    );
  }
}