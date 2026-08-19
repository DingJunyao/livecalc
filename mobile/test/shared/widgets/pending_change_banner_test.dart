import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/shared/widgets/pending_change_banner.dart';

void main() {
  testWidgets('pending changes are consolidated into one notice', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PendingChangeBanner(
            modifications: {'总时间', '做法步骤'},
            deletions: {'自定义单位'},
          ),
        ),
      ),
    );

    expect(
      find.text('待管理员审核：修改总时间、做法步骤、删除自定义单位'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.hourglass_top_outlined), findsOneWidget);
  });

  testWidgets('audit-only fields are hidden from pending notices', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PendingChangeBanner(
            modifications: {'名称', 'updated_by', 'update_by'},
          ),
        ),
      ),
    );

    expect(find.text('修改待管理员审核：名称'), findsOneWidget);
    expect(find.textContaining('updated_by'), findsNothing);
    expect(find.textContaining('update_by'), findsNothing);
  });
}
