import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/profile/models/proposal.dart';
import 'package:com_a4ding_livecalc/features/profile/providers/profile_provider.dart';
import 'package:com_a4ding_livecalc/features/profile/repositories/profile_repository.dart';
import 'package:com_a4ding_livecalc/features/profile/screens/my_proposals_screen.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

const _approved = Proposal(
  id: 1,
  entityType: 'ingredient',
  entityId: 42,
  entityLabel: '番茄',
  action: 'update',
  payload: {'name': '西红柿', 'unit_id': 3},
  snapshot: {'name': '番茄', 'unit_id': 3},
  status: 'approved',
  reviewNote: '命名规范',
  createdAt: '2026-08-01 10:00',
);
const _pending = Proposal(
  id: 2,
  entityType: 'unit',
  action: 'create',
  payload: {'name': '打'},
  status: 'pending',
  createdAt: '2026-08-02 09:00',
);

void main() {
  late MockProfileRepository mockRepo;

  setUp(() {
    mockRepo = MockProfileRepository();
    when(() => mockRepo.getProposals())
        .thenAnswer((_) async => [_approved, _pending]);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        proposalListProvider
            .overrideWith((ref) => ProposalListNotifier(mockRepo)),
      ],
      child: const MaterialApp(home: MyProposalsScreen()),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('列表：标题、类型/动作/时间、中文状态', (tester) async {
    await pumpScreen(tester);

    // entityLabel 作标题
    expect(find.text('番茄'), findsOneWidget);
    // 缺失 entityLabel 回退
    expect(find.text('[#2] create unit'), findsOneWidget);
    // subtitle
    expect(find.textContaining('食材 · 修改 · 2026-08-01 10:00'), findsOneWidget);
    expect(find.textContaining('单位 · 新增 · 2026-08-02 09:00'), findsOneWidget);
    // 状态 chip
    expect(find.text('已生效'), findsOneWidget);
    expect(find.text('待审'), findsOneWidget);
  });

  testWidgets('点击条目弹出详情：状态/审核意见/变更 diff', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.text('番茄'));
    await tester.pumpAndSettle();

    expect(find.text('提议 #1'), findsOneWidget);
    expect(find.text('已生效'), findsWidgets); // 列表 chip + dialog chip
    expect(find.text('审核意见'), findsOneWidget);
    expect(find.text('命名规范'), findsOneWidget);
    expect(find.text('变更内容'), findsOneWidget);
    // snapshot vs payload：name 变了，unit_id 相同不展示
    expect(find.textContaining('name：'), findsOneWidget);
    expect(find.textContaining('unit_id'), findsNothing);

    await tester.tap(find.text('关闭'));
    await tester.pumpAndSettle();
    expect(find.text('提议 #1'), findsNothing);
  });
}
