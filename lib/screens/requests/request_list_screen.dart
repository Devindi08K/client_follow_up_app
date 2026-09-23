import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/request_service.dart';
import '../../theme/app_theme.dart';
import 'request_detail_screen.dart';

enum RequestListFilter { active, overdue, completed, all }

class RequestListScreen extends StatefulWidget {
  final RequestListFilter filter;
  final String title;

  const RequestListScreen({super.key, required this.filter, required this.title});

  @override
  State<RequestListScreen> createState() => _RequestListScreenState();
}

class _RequestListScreenState extends State<RequestListScreen> {
  final _requestService = RequestService();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await _requestService.fetchRequestsOverview();
      final now = DateTime.now();

      bool matches(Map<String, dynamic> row) {
        final status = row['status'] as String? ?? 'pending';
        final dueDate = _parseDate(row['due_date']);
        final isPastDue = dueDate != null && dueDate.isBefore(now);
        final isOverdue = status == 'overdue' || (isPastDue && status != 'complete' && status != 'cancelled');

        switch (widget.filter) {
          case RequestListFilter.active:
            return status == 'pending' || status == 'overdue';
          case RequestListFilter.overdue:
            return isOverdue;
          case RequestListFilter.completed:
            return status == 'complete';
          case RequestListFilter.all:
            return true;
        }
      }

      final filtered = all.where(matches).toList();
      if (!mounted) return;
      setState(() {
        _rows = filtered;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.MMMd();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
              ? ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Text('Nothing here yet.',
                      style: TextStyle(color: context.palette.textSecondary)),
                ),
              ),
            ],
          )
              : ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final row = _rows[index];
              final client = row['clients'] as Map<String, dynamic>?;
              final status = row['status'] as String? ?? 'pending';
              final items = (row['request_items'] as List?) ?? [];
              final missing =
                  items.where((i) => (i as Map)['status'] != 'received').length;
              final dueDate = _parseDate(row['due_date']);

              return Container(
                decoration: BoxDecoration(
                  color: context.palette.surface1,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.palette.border),
                ),
                child: ListTile(
                  title: Text(client?['name'] as String? ?? 'Unknown client',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${row['title'] as String? ?? 'Request'} · '
                        '${missing == 0 ? 'All items received' : '$missing missing'}'
                        '${dueDate != null ? ' · Due ${dateFormat.format(dueDate)}' : ''}',
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppStatusColors.forStatus(status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                        color: AppStatusColors.forStatus(status),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RequestDetailScreen(requestId: row['id'] as String),
                      ),
                    );
                    _load();
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}