import 'package:flutter_test/flutter_test.dart';

import 'package:client_follow_up_app/main.dart';

void main() {
  testWidgets('Login screen is displayed', (WidgetTester tester) async {
    await tester.pumpWidget(const ClientFollowUpApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
