import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/business_service.dart';
import '../../services/auth_service.dart';
import '../../services/request_service.dart';
import '../../theme/app_theme.dart';
import '../clients/client_list_screen.dart';
import '../requests/new_request_wizard/new_request_wizard_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await AuthService().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Account';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client Follow-Up'),
        actions: [
          IconButton(
            tooltip: 'Clients',
            icon: const Icon(Icons.people_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ClientListScreen(),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_outlined),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: BusinessService().streamBusinessProfile(),
          builder: (context, snapshot) {
            String businessName = 'Your Business';

            if (snapshot.hasData && snapshot.data!.exists) {
              businessName =
                  snapshot.data!.data()?['name'] as String? ?? 'Your Business';
            }

            final loading =
                snapshot.connectionState == ConnectionState.waiting;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good to see you',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  if (loading)
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      businessName,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppColors.inkSoft),
                    ),
                  const SizedBox(height: 28),
                  Text(
                    email,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Overview',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),

                  // Real request statistics
                  StreamBuilder<List<Map<String, dynamic>>>(
                    stream: RequestService().streamAllRequests(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Dashboard error: ${snapshot.error}',
                            style: const TextStyle(color: AppColors.rust),
                          ),
                        );
                      }
                      final requests = snapshot.data ?? [];

                      final active = requests
                          .where((r) => r['status'] == 'pending')
                          .length;

                      final overdue = requests
                          .where((r) => r['status'] == 'overdue')
                          .length;

                      final complete = requests
                          .where((r) => r['status'] == 'complete')
                          .length;

                      // Count unique clients from the requests.
                      final clientIds = requests
                          .map((r) => r['clientId'])
                          .where((id) => id != null)
                          .toSet();

                      final clients = clientIds.length;

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                        const ClientListScreen(),
                                      ),
                                    );
                                  },
                                  child: _StatCard(
                                    title: 'Active',
                                    value: '$active',
                                    icon: Icons.pending_actions_outlined,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                        const ClientListScreen(),
                                      ),
                                    );
                                  },
                                  child: _StatCard(
                                    title: 'Completed',
                                    value: '$complete',
                                    icon: Icons.check_circle_outline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                        const ClientListScreen(),
                                      ),
                                    );
                                  },
                                  child: _StatCard(
                                    title: 'Overdue',
                                    value: '$overdue',
                                    icon: Icons.warning_amber_outlined,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                        const ClientListScreen(),
                                      ),
                                    );
                                  },
                                  child: _StatCard(
                                    title: 'Clients',
                                    value: '$clients',
                                    icon: Icons.people_outline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 32),

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
                          Icons.assignment_outlined,
                          size: 32,
                          color: AppColors.sageDeep,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'No follow-up requests yet',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Create your first client request to start collecting '
                              'documents and information.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.inkSoft),
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final created = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                const NewRequestWizardScreen(),
                              ),
                            );

                            if (created == true && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Request created.'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create request'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paperRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppColors.sageDeep,
            size: 25,
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}