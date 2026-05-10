import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_app/features/auth/presentation/login_screen.dart';
import 'package:couple_app/features/auth/presentation/register_screen.dart';
import 'package:couple_app/features/couple/presentation/onboarding_screen.dart';

void main() {
  testWidgets('Login form: empty submit shows validation errors', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Giriş yap'));
    await tester.pump();

    expect(find.text('E-posta gerekli'), findsOneWidget);
    expect(find.text('En az 8 karakter'), findsOneWidget);
  });

  testWidgets('Register form: invalid email rejected', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: RegisterScreen()),
      ),
    );

    await tester.enterText(find.widgetWithText(TextFormField, 'Görünen ad'), 'Alice');
    await tester.enterText(find.widgetWithText(TextFormField, 'E-posta'), 'not-an-email');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Parola (min. 8 karakter)'), 'Password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Kayıt ol'));
    await tester.pump();

    expect(find.text('Geçerli bir e-posta gir'), findsOneWidget);
  });

  testWidgets('Onboarding shows two CTAs', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: OnboardingScreen()),
      ),
    );

    expect(find.text('Davet kodu oluştur'), findsOneWidget);
    expect(find.text('Partner kodunu gir / QR tara'), findsOneWidget);
  });
}
