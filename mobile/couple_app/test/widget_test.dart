import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:couple_app/features/auth/presentation/login_screen.dart';
import 'package:couple_app/features/auth/presentation/register_screen.dart';
import 'package:couple_app/features/couple/presentation/onboarding_screen.dart';
import 'package:couple_app/core/theme/app_theme.dart';

Widget _wrap(Widget child) => ProviderScope(
      child: MaterialApp(theme: AppTheme.light(), home: child),
    );

void main() {
  testWidgets('Login form: empty submit shows validation errors',
      (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Giriş yap'));
    await tester.pump();

    expect(find.text('E-posta gerekli'), findsOneWidget);
    expect(find.text('En az 8 karakter'), findsOneWidget);
  });

  testWidgets('Register form: invalid email rejected', (tester) async {
    await tester.pumpWidget(_wrap(const RegisterScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'Alice');
    await tester.enterText(find.byType(TextFormField).at(1), 'not-an-email');
    await tester.enterText(find.byType(TextFormField).at(2), 'Password123');
    await tester.tap(find.text('Hesabımı aç'));
    await tester.pump();

    expect(find.text('Geçerli bir e-posta gir'), findsOneWidget);
  });

  testWidgets('Onboarding shows two CTAs', (tester) async {
    await tester.pumpWidget(_wrap(const OnboardingScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Ben başlatayım'), findsOneWidget);
    expect(find.text('O bana verdi'), findsOneWidget);
  });
}
