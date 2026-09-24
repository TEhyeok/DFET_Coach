import 'package:dfet_coach/widgets/protein_foods_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('고단백 식품 선택은 호출 화면을 닫지 않고 식품 결과를 반환한다', (tester) async {
    Object? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                const Text('홈 화면'),
                FilledButton(
                  onPressed: () async {
                    selected = await showDialog<Object?>(
                      context: context,
                      builder: (_) => const ProteinFoodsDialog(),
                    );
                  },
                  child: const Text('가이드 열기'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('가이드 열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('닭가슴살'));
    await tester.pumpAndSettle();

    expect(find.text('홈 화면'), findsOneWidget);
    expect(find.byType(ProteinFoodsDialog), findsNothing);
    expect(
      selected,
      isA<Map>().having(
        (value) => (value['food'] as Map)['name'],
        '식품명',
        '닭가슴살',
      ),
    );
  });
}
