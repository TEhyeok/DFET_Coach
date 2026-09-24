import 'package:dfet_coach/screens/subscription_screen.dart';
import 'package:dfet_coach/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('subscription remains gated until server verification exists',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appThemeLight(),
        home: const SubscriptionScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('멤버십 판매 준비 중'), findsOneWidget);
    expect(find.textContaining('결제 요청이나 임의 가격 표시'), findsOneWidget);
    expect(find.textContaining('₩'), findsNothing);
    expect(find.text('구매하기'), findsNothing);
  });
}
