import 'package:dfet_coach/models/soap_note.dart';
import 'package:dfet_coach/screens/trainer/trainer_soap_notes_screen.dart';
import 'package:dfet_coach/state/soap_note_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('trainer SOAP editor supports iPad sections and validation',
      (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          soapNotesProvider.overrideWith((ref) async => <SoapNote>[]),
        ],
        child: const CupertinoApp(
          home: TrainerSoapNotesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('트레이너 현황'), findsOneWidget);
    expect(find.text('새 SOAP 노트'), findsOneWidget);
    expect(find.text('기본정보'), findsOneWidget);
    expect(find.text('회원명'), findsOneWidget);

    await tester.tap(find.text('O').first);
    await tester.pumpAndSettle();
    expect(find.text('O. 객관적 정보'), findsOneWidget);

    await tester.tap(find.text('행 추가').first);
    await tester.pumpAndSettle();
    expect(find.text('항목'), findsOneWidget);

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('회원명을 입력해주세요'), findsOneWidget);
  });
}
