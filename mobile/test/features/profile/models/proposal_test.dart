import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/profile/models/proposal.dart';

void main() {
  test('fromJson 解析真实后端形状', () {
    final p = Proposal.fromJson({
      'id': 7,
      'entity_type': 'ingredient',
      'entity_id': 42,
      'entity_label': '番茄',
      'action': 'update',
      'payload': {'name': '西红柿', 'unit_id': 3},
      'snapshot': {'name': '番茄', 'unit_id': 3},
      'status': 'approved',
      'review_note': '命名规范',
      'created_at': '2026-08-01 10:00',
    });

    expect(p.id, 7);
    expect(p.entityType, 'ingredient');
    expect(p.entityId, 42);
    expect(p.action, 'update');
    expect(p.payload['name'], '西红柿');
    expect(p.snapshot['name'], '番茄');
    expect(p.status, 'approved');
    expect(p.reviewNote, '命名规范');
    expect(p.createdAt, '2026-08-01 10:00');
    expect(p.title, '番茄');
    expect(p.description, '命名规范');
  });

  test('title 回退：entity_label 缺失时用 [#id] action type', () {
    final p = Proposal.fromJson({
      'id': 3,
      'entity_type': 'unit',
      'action': 'create',
      'payload': {'name': '打'},
      'status': 'pending',
    });

    expect(p.title, '[#3] create unit');
    expect(p.description, '');
  });

  test('payload/snapshot 缺失容错为空 Map', () {
    final p = Proposal.fromJson({
      'id': 1,
      'entity_type': 'merchant',
      'entity_id': 9,
      'action': 'delete',
      'status': 'rejected',
    });

    expect(p.payload, isEmpty);
    expect(p.snapshot, isEmpty);
  });
}
