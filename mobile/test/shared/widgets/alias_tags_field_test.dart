import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/shared/widgets/alias_tags_field.dart';

void main() {
  testWidgets('别名提示使用跨平台文案，逗号和空格保持原样', (tester) async {
    final tags = <List<String>>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AliasTagsField(
          label: '别名',
          onTagsChanged: tags.add,
        ),
      ),
    ));

    expect(find.text('输入后点击 + 添加'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '番茄, 西红柿');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.byType(Chip), findsOneWidget);
    expect(find.text('番茄, 西红柿'), findsOneWidget);
    expect(tags, [
      ['番茄, 西红柿']
    ]);
  });

  testWidgets('添加按钮同样提交，重复别名不追加', (tester) async {
    final tags = <List<String>>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AliasTagsField(
          label: '别名',
          onTagsChanged: tags.add,
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), '红 萝卜');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '红 萝卜');
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.byType(Chip), findsOneWidget);
    expect(tags, [
      ['红 萝卜'],
    ]);
  });

  testWidgets('预填别名可以删除', (tester) async {
    final tags = <List<String>>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AliasTagsField(
          label: '别名',
          initialTags: const ['鸡蛋'],
          onTagsChanged: tags.add,
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(find.byType(Chip), findsNothing);
    expect(tags.last, isEmpty);
  });
}
