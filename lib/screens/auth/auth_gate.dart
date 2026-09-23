import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../dashboard/dashboard_screen.dart';
import 'login_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  bool _hadSession = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session ??
            Supabase.instance.client.auth.currentSession;
        final event = snapshot.data?.event;

        if (session != null) {
          _hadSession = true;
          return const DashboardScreen();
        }

        // Session dropped after we'd previously seen one signed in — that's
        // an expiry, not a fresh app start, so tell the user why they're
        // back at login (GLOBAL_READINESS §1.AA — session expiry handling).
        if (_hadSession && event != AuthChangeEvent.signedOut) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Your session expired. Please sign in again.')),
            );
          });
        }
        _hadSession = false;

        return const LoginScreen();
      },
    );
  }
}