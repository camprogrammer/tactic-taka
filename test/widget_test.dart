import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:football_social_app/app/app.dart';

void main() {
  testWidgets('App renders board screen shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FootballSocialApp()));
    await tester.pumpAndSettle();

    expect(find.text('전술 보드'), findsOneWidget);
  });
}
