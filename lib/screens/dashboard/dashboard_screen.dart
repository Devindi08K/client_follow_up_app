import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../services/business_service.dart';
import '../../services/client_service.dart';
import '../../services/request_service.dart';
import '../../theme/app_theme.dart';
import '../requests/new_request_wizard/new_request_wizard_screen.dart';
import '../requests/request_detail_screen.dart';
import '../requests/request_list_screen.dart';
import '../clients/client_list_screen.dart';
import '../settings/settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _FollowUpRow {
  final String requestId;
  final String clientName;
  final String title;
  final int missingCount;
  final DateTime? dueDate;
  final DateTime? nextFollowUpAt;
  final bool isOverdue;

  _FollowUpRow({
    required this.requestId,
    required this.clientName,
    required this.title,
    required this.missingCount,
    required this.dueDate,
    required this.nextFollowUpAt,
    required this.isOverdue,
  });
}

class _DashboardStats {
  final int active;
  final int overdue;
  final int completed;
  final int clients;
  final List<_FollowUpRow> followUpsDue;

  _DashboardStats({
    required this.active,
    required this.overdue,
    required this.completed,
    required this.clients,
    required this.followUpsDue,
  });

  static _DashboardStats empty() =>
      _DashboardStats(active: 0, overdue: 0, completed: 0, clients: 0, followUpsDue: []);
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _businessService = BusinessService();
  final _requestService = RequestService();
  final _clientService = ClientService();

  String _businessName = 'Your Business';
  bool _loadingProfile = true;
  bool _loadingStats = true;
  _DashboardStats _stats = _DashboardStats.empty();

  @override
  void initState() {
    super.initState();
    _loadBusinessProfile();
    _loadStats();
  }

  Future<void> _loadBusinessProfile() async {
    try {
      final data = await _businessService.ensureBusinessProfile();
      if (!mounted) return;
      setState(() {
        _businessName = data?['name'] as String? ?? 'Your Business';
        _loadingProfile = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProfile = false);
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    try {
      final results = await Future.wait([
        _requestService.fetchRequestsOverview(),
        _clientService.countClients(),
      ]);

      final requests = results[0] as List<Map<String, dynamic>>;
      final clientCount = results[1] as int;
      final now = DateTime.now();

      var active = 0;
      var overdue = 0;
      var completed = 0;
      final followUps = <_FollowUpRow>[];

      for (final row in requests) {
        final status = row['status'] as String? ?? 'pending';
        if (status == 'cancelled') continue;
        if (status == 'complete') {
          completed++;
          continue;
        }

        final dueDate = _parseDate(row['due_date']);
        final nextFollowUpAt = _parseDate(row['next_follow_up_at']);
        final isPastDue = dueDate != null && dueDate.isBefore(now);
        final isOverdue = status == 'overdue' || isPastDue;

        active++;
        if (isOverdue) overdue++;

        final items = (row['request_items'] as List?) ?? [];
        final missingCount = items.where((i) => (i as Map)['status'] != 'received').length;

        final client = row['clients'] as Map<String, dynamic>?;
        final isDue = isOverdue || (nextFollowUpAt != null && !nextFollowUpAt.isAfter(now));

        if (isDue && missingCount > 0) {
          followUps.add(_FollowUpRow(
            requestId: row['id'] as String,
            clientName: client?['name'] as String? ?? 'Unknown client',
            title: row['title'] as String? ?? 'Request',
            missingCount: missingCount,
            dueDate: dueDate,
            nextFollowUpAt: nextFollowUpAt,
            isOverdue: isOverdue,
          ));
        }
      }

      followUps.sort((a, b) {
        if (a.isOverdue != b.isOverdue) return a.isOverdue ? -1 : 1;
        final aDate = a.nextFollowUpAt ?? a.dueDate;
        final bDate = b.nextFollowUpAt ?? b.dueDate;
        if (aDate == null || bDate == null) return 0;
        return aDate.compareTo(bDate);
      });

      if (!mounted) return;
      setState(() {
        _stats = _DashboardStats(
          active: active,
          overdue: overdue,
          completed: completed,
          clients: clientCount,
          followUpsDue: followUps,
        );
        _loadingStats = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingStats = false);
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String);
  }

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();
  }

  Future<void> _openNewRequest() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NewRequestWizardScreen()),
    );
    if (created == true) {
      _loadStats();
    }
  }

  Future<void> _openRequest(String requestId) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RequestDetailScreen(requestId: requestId)),
    );
    _loadStats();
  }
  Future<void> _openList(RequestListFilter filter, String title) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RequestListScreen(
          filter: filter,
          title: title,
        ),
      ),
    );
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'Account';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Follow-Up'),
        actions: [
          IconButton(                                              // ← new
            tooltip: 'Settings',                                    // ← new
            icon: const Icon(Icons.settings_outlined),               // ← new
            onPressed: () => Navigator.push(                         // ← new
              context,                                                // ← new
              MaterialPageRoute(builder: (_) => const SettingsScreen()), // ← new
            ),                                                        // ← new
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_outlined),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_loadBusinessProfile(), _loadStats()]);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good to see you',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                if (_loadingProfile)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    _businessName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
                  ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
                const SizedBox(height: 28),
                Text(
                  'Overview',
                  style:
                  Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Active',
                        value: '${_stats.active}',
                        icon: Icons.pending_actions_outlined,
                        onTap: () => _openList(
                          RequestListFilter.active,
                          'Active requests',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Completed',
                        value: '${_stats.completed}',
                        icon: Icons.check_circle_outline,
                        onTap: () => _openList(
                          RequestListFilter.completed,
                          'Completed requests',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Overdue',
                        value: '${_stats.overdue}',
                        icon: Icons.warning_amber_outlined,
                        onTap: () => _openList(
                          RequestListFilter.overdue,
                          'Overdue requests',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Clients',
                        value: '${_stats.clients}',
                        icon: Icons.people_outline,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ClientListScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Follow-ups due',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    TextButton.icon(
                      onPressed: _openNewRequest,
                      icon: const Icon(Icons.add),
                      label: const Text('New request'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_loadingStats)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_stats.followUpsDue.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.paperRaised,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 32,
                          color: AppColors.sageDeep,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _stats.active == 0 ? 'No follow-up requests yet' : "Nothing's due right now",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _stats.active == 0
                              ? 'Create your first client request to start tracking follow-ups.'
                              : "You're all caught up with clients for now.",
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.inkSoft),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _openNewRequest,
                          icon: const Icon(Icons.add),
                          label: const Text('Create request'),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: _stats.followUpsDue
                        .map((row) => _FollowUpCard(row: row, onTap: () => _openRequest(row.requestId)))
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  const _StatCard({required this.title, required this.value, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.paperRaised,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.sageDeep, size: 25),
            const SizedBox(height: 14),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  final _FollowUpRow row;
  final VoidCallback onTap;

  const _FollowUpCard({required this.row, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusKey = row.isOverdue ? 'overdue' : 'pending';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.paperRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        title: Text(row.clientName, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${row.missingCount} item${row.missingCount == 1 ? '' : 's'} missing · ${row.title}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.forStatus(statusKey).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            row.isOverdue ? 'Overdue' : 'Due today',
            style: TextStyle(
              color: AppColors.forStatus(statusKey),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}