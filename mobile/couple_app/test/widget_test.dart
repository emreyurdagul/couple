import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:couple_app/main.dart';

void main() {
  testWidgets('App boots with placeholder screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CoupleApp()));
    await tester.pumpAndSettle();
    expect(find.text('İskelet hazır.'), findsOneWidget);
  });
}
