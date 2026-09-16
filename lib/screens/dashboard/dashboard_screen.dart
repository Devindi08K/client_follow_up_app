import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/business_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _businessService = BusinessService();

  String _businessName = 'Your Business';
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadBusinessProfile();
  }

  Future<void> _loadBusinessProfile() async {
    try {
      final snapshot = await _businessService.getBusinessProfile();

      if (!mounted) return;

      if (snapshot.exists) {
        final data = snapshot.data();

        setState(() {
          _businessName = data?['name'] as String? ?? 'Your Business';
          _loadingProfile = false;
        });
      } else {
        setState(() {
          _loadingProfile = false;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingProfile = false;
      });
    }
  }

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
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_outlined),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
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

              if (_loadingProfile)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  _businessName,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: AppColors.inkSoft),
                ),

              const SizedBox(height: 28),
              Text(
                email,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.inkSoft,
                ),
              ),

              Text(
                'Overview',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Active',
                      value: '0',
                      icon: Icons.pending_actions_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Completed',
                      value: '0',
                      icon: Icons.check_circle_outline,
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
                      value: '0',
                      icon: Icons.warning_amber_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Clients',
                      value: '0',
                      icon: Icons.people_outline,
                    ),
                  ),
                ],
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
                      onPressed: () {
                        // Request creation will be connected in the next
                        // feature step.
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Create request'),
                    ),
                  ],
                ),
              ),
            ],
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
          Icon(icon, color: AppColors.sageDeep, size: 25),
          const SizedBox(height: 14),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}
