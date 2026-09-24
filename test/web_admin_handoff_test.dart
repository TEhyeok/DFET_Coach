import 'package:dfet_coach/web_admin_handoff.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('legacy Flutter admin is replaced by the Next.js handoff',
      (tester) async {
    await tester.pumpWidget(const WebAdminHandoffApp());
    await tester.pumpAndSettle();

    expect(find.text('D-FET 관리자 웹 전환'), findsOneWidget);
    expect(find.text('배포 설정 필요'), findsOneWidget);

    final button = tester.widget<FilledButton>(find.bySubtype<FilledButton>());
    expect(button.onPressed, isNull);
  });
}
