import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/auth/auth_gate.dart';
import 'services/theme_service.dart';
import 'theme/app_theme.dart';
import 'widgets/offline_banner.dart';
import 'services/purchase_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  await PurchaseService().configure();
  await ThemeService.instance.load();
  await NotificationService.instance.init();

  runApp(const ClientFollowUpApp());
}

class ClientFollowUpApp extends StatelessWidget {
  const ClientFollowUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Client Follow-Up',
          debugShowCheckedModeBanner: false,
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: ThemeService.instance.mode,
          builder: (context, child) => OfflineBanner(child: child!),
          home: const AuthGate(),
        );
      },
    );
  }
}