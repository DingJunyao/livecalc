import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/calc_scope/models/calc_scope.dart';
import 'package:com_a4ding_livecalc/features/calc_scope/providers/calc_scope_provider.dart';
import 'package:com_a4ding_livecalc/features/calc_scope/repositories/calc_scope_repository.dart';

class _FakeCalcScopeRepository extends CalcScopeRepository {
  final List<CalcScope> seed;
  Map<String, dynamic>? lastCreated;
  Map<String, dynamic>? lastUpdated;
  List<int> removed = [];

  _FakeCalcScopeRepository(this.seed);

  @override
  Future<List<CalcScope>> listScopes() async => seed;

  @override
  Future<CalcScope> createScope(Map<String, dynamic> body) async {
    lastCreated = body;
    return seed.first;
  }

  @override
  Future<CalcScope> updateScope(int id, Map<String, dynamic> body) async {
    lastUpdated = body;
    return seed.first;
  }

  @override
  Future<void> deleteScope(int id) async {
    removed.add(id);
  }
}

CalcScope _scope(int id, {bool isDefault = false}) => CalcScope(
      id: id,
      name: '范围$id',
      regionIds: [id],
      isDefault: isDefault,
    );

void main() {
  test('load 填充 items 并清除 loading/error', () async {
    final repo = _FakeCalcScopeRepository([_scope(1)]);
    final notifier = CalcScopeListNotifier(repo);

    await notifier.load();

    expect(notifier.state.loading, isFalse);
    expect(notifier.state.error, isNull);
    expect(notifier.state.items.length, 1);
    expect(notifier.state.items.first.name, '范围1');
  });

  test('load 失败记录 error 并结束 loading', () async {
    final notifier = CalcScopeListNotifier(_FailingRepository());

    await notifier.load();

    expect(notifier.state.loading, isFalse);
    expect(notifier.state.error, isNotNull);
  });

  test('add/update/remove 落库后重新 load', () async {
    final repo = _FakeCalcScopeRepository([_scope(1), _scope(2)]);
    final notifier = CalcScopeListNotifier(repo);

    await notifier.load();
    await notifier.add({'name': '新范围', 'region_ids': [3]});
    expect(repo.lastCreated?['name'], '新范围');
    expect(notifier.state.items.length, 2);

    await notifier.update(1, {'name': '改名'});
    expect(repo.lastUpdated?['name'], '改名');

    await notifier.remove(2);
    expect(repo.removed, [2]);
  });
}

class _FailingRepository extends CalcScopeRepository {
  @override
  Future<List<CalcScope>> listScopes() async {
    throw Exception('network down');
  }
}
