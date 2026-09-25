import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:client_follow_up_app/config/supabase_config.dart';
import 'package:client_follow_up_app/main.dart';

void main() {
  setUpAll(() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  });

  testWidgets('Login screen is displayed', (WidgetTester tester) async {
    await tester.pumpWidget(const ClientFollowUpApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}