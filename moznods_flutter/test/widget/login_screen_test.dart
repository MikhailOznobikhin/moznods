import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:moznods_flutter/l10n/app_localizations.dart';
import 'package:moznods_flutter/l10n/app_localizations_en.dart';
import 'package:moznods_flutter/ui/screens/login_screen.dart';

Widget createTestWidget(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
      locale: const Locale('en'),
      home: child,
    ),
  );
}

void main() {
  group('LoginScreen', () {
    testWidgets('renders login form elements', (tester) async {
      await tester.pumpWidget(createTestWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('shows validation error for empty fields', (tester) async {
      await tester.pumpWidget(createTestWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      final loginButton = find.byType(ElevatedButton);
      await tester.tap(loginButton);
      await tester.pumpAndSettle();

      expect(find.text('Username is required'), findsOneWidget);
      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('can enter username and password', (tester) async {
      await tester.pumpWidget(createTestWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'testuser');
      await tester.enterText(textFields.at(1), 'password123');
      await tester.pump();

      expect(find.text('testuser'), findsOneWidget);
      expect(find.text('password123'), findsOneWidget);
    });

    testWidgets('has register link', (tester) async {
      await tester.pumpWidget(createTestWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      expect(find.text("Don't have an account? Register"), findsOneWidget);
    });
  });
}
