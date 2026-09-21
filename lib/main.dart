import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/auth/auth_gate.dart';
import 'theme/app_theme.dart';
import 'widgets/offline_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  runApp(const ClientFollowUpApp());
}

class ClientFollowUpApp extends StatelessWidget {
  const ClientFollowUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Client Follow-Up',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      builder: (context, child) => OfflineBanner(child: child!),
      home: const AuthGate(),
    );
  }
}