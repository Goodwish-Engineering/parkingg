import 'package:flutter_test/flutter_test.dart';

import 'package:parking/auth/loginpage.dart';
import 'package:parking/main.dart';

void main() {
  testWidgets('app starts and shows login screen when not logged in',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(isLoggedIn: false));
    await tester.pump();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('app shows sign-in text on login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(isLoggedIn: false));
    await tester.pump();

    expect(find.text('Sign In'), findsOneWidget);
  });
}
