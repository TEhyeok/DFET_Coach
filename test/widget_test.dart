import 'package:dfet_coach/models/record_types.dart';
import 'package:dfet_coach/widgets/shells/ios_destination.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('iOS shell destinations render in a ProviderScope app',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: CupertinoApp(
          home: _DestinationSmokeView(),
        ),
      ),
    );

    expect(find.text('홈'), findsOneWidget);
    expect(find.text('기록'), findsOneWidget);
    expect(find.text('코칭'), findsOneWidget);
    expect(find.text('커뮤니티'), findsOneWidget);
    expect(find.text('내 정보'), findsOneWidget);
    expect(RecordSection.values, hasLength(3));
  });
}

class _DestinationSmokeView extends StatelessWidget {
  const _DestinationSmokeView();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Column(
        children: [
          for (final destination in IOSDestination.values)
            Text(destination.label),
        ],
      ),
    );
  }
}
