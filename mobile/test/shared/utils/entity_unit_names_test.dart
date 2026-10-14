import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/shared/utils/entity_unit_names.dart';

/// 记录请求路径并返回预设响应的假请求缝（替代真实 ApiClient/Dio）。
class _FakeRequest {
  _FakeRequest(this.responses, {this.failures = const <String>{}});

  final Map<String, Object?> responses;
  final Set<String> failures;
  final List<String> calls = [];

  Future<Object?> call(String path) async {
    calls.add(path);
    if (failures.contains(path)) {
      throw StateError('boom: $path');
    }
    if (!responses.containsKey(path)) {
      throw StateError('unexpected path: $path');
    }
    return responses[path];
  }
}

void main() {
  group('loadEntityUnitNames', () {
    test('商品自身覆盖在前，关联原料覆盖在后，按名称去重', () async {
      final fake = _FakeRequest({
        '/entities/product/42/units': [
          {'unit_name': '桶'},
          {'unit_name': '桶'},
        ],
        '/entities/ingredient/7/units': [
          {'unit_name': '桶'},
          {'unit_name': '把'},
        ],
      });

      final names = await loadEntityUnitNames(
        entityType: 'product',
        entityId: 42,
        ingredientId: 7,
        request: fake.call,
      );

      expect(names, ['桶', '把']);
      expect(fake.calls, [
        '/entities/product/42/units',
        '/entities/ingredient/7/units',
      ]);
    });

    test('未传 ingredientId 时回查 /products/entity/{id} 再查原料单位', () async {
      final fake = _FakeRequest({
        '/entities/product/42/units': const <Object?>[],
        '/products/entity/42': {'id': 42, 'ingredient_id': 7},
        '/entities/ingredient/7/units': [
          {'unit_name': '桶'},
        ],
      });

      final names = await loadEntityUnitNames(
        entityType: 'product',
        entityId: 42,
        request: fake.call,
      );

      expect(names, ['桶']);
      expect(fake.calls, [
        '/entities/product/42/units',
        '/products/entity/42',
        '/entities/ingredient/7/units',
      ]);
    });

    test('ingredient 实体只查一次，不做原料回退', () async {
      final fake = _FakeRequest({
        '/entities/ingredient/7/units': [
          {'unit_name': '桶'},
        ],
      });

      final names = await loadEntityUnitNames(
        entityType: 'ingredient',
        entityId: 7,
        request: fake.call,
      );

      expect(names, ['桶']);
      expect(fake.calls, ['/entities/ingredient/7/units']);
    });

    test('name 键的行同样识别（与 web frontend/src/utils/entityUnits.ts 同口径）', () async {
      final fake = _FakeRequest({
        '/entities/product/42/units': [
          {'name': '箱'},
        ],
        '/entities/ingredient/7/units': [
          {'name': '盒', 'unit_name': null},
        ],
      });

      final names = await loadEntityUnitNames(
        entityType: 'product',
        entityId: 42,
        ingredientId: 7,
        request: fake.call,
      );

      expect(names, ['箱', '盒']);
    });

    test('跳过 is_active=false / 0 / "false" 的行', () async {
      final fake = _FakeRequest({
        '/entities/product/42/units': [
          {'unit_name': '桶', 'is_active': true},
          {'unit_name': '停用1', 'is_active': false},
          {'unit_name': '停用2', 'is_active': 0},
          {'unit_name': '停用3', 'is_active': 'false'},
          {'unit_name': '停用4', 'is_active': '0'},
          {'unit_name': '箱'},
        ],
      });

      final names = await loadEntityUnitNames(
        entityType: 'product',
        entityId: 42,
        request: fake.call,
      );

      expect(names, ['桶', '箱']);
    });

    test('响应为 {items:[...]} 包裹也能解析，非 Map/空名字的行被忽略', () async {
      final fake = _FakeRequest({
        '/entities/product/42/units': {
          'items': [
            {'unit_name': '  桶  '},
            {'unit_name': ''},
            {'unit_name': '   '},
            {'name': null},
            'not-a-map',
            42,
          ],
          'total': 6,
        },
      });

      final names = await loadEntityUnitNames(
        entityType: 'product',
        entityId: 42,
        request: fake.call,
      );

      expect(names, ['桶']);
    });

    test('商品单位请求失败 → 空列表，不抛（只吞请求，不吞解析）', () async {
      final fake = _FakeRequest(
        const {},
        failures: {'/entities/product/42/units'},
      );

      final names = await loadEntityUnitNames(
        entityType: 'product',
        entityId: 42,
        request: fake.call,
      );

      expect(names, isEmpty);
    });

    test('原料回查失败 → 商品自身单位仍返回，不抛', () async {
      final fake = _FakeRequest(
        {
          '/entities/product/42/units': [
            {'unit_name': '桶'},
          ],
        },
        failures: {'/products/entity/42'},
      );

      final names = await loadEntityUnitNames(
        entityType: 'product',
        entityId: 42,
        request: fake.call,
      );

      expect(names, ['桶']);
    });

    test('关联原料单位请求失败 → 商品自身单位仍返回，不抛', () async {
      final fake = _FakeRequest(
        {
          '/entities/product/42/units': [
            {'unit_name': '桶'},
          ],
          '/entities/ingredient/7/units': [
            {'unit_name': '把'},
          ],
        },
        failures: {'/entities/ingredient/7/units'},
      );

      final names = await loadEntityUnitNames(
        entityType: 'product',
        entityId: 42,
        ingredientId: 7,
        request: fake.call,
      );

      expect(names, ['桶']);
    });
  });

  group('loadGlobalUnitNames', () {
    test('取 abbreviation（缺省 name），去重去空', () async {
      final fake = _FakeRequest({
        '/units/?limit=500': [
          {'abbreviation': '斤', 'name': '斤'},
          {'abbreviation': 'mL', 'name': '毫升'},
          {'abbreviation': 'mL', 'name': '毫升'},
          {'abbreviation': '', 'name': '桶'},
          {'abbreviation': null, 'name': null},
        ],
      });

      final names = await loadGlobalUnitNames(request: fake.call);

      expect(names, ['斤', 'mL', '桶']);
    });

    test('请求失败 → 空列表（调用方回退硬编码常量），不抛', () async {
      final fake = _FakeRequest(
        const {},
        failures: {'/units/?limit=500'},
      );

      expect(await loadGlobalUnitNames(request: fake.call), isEmpty);
    });
  });

  group('loadEntityDefaultUnitName', () {
    test('商品自身的默认单位优先于关联原料的默认单位', () async {
      final fake = _FakeRequest({
        '/entities/product/42/units': [
          {'unit_name': '桶', 'is_default': false},
          {'unit_name': '箱', 'is_default': true},
        ],
        '/entities/ingredient/7/units': [
          {'unit_name': '盒', 'is_default': true},
        ],
      });

      final name = await loadEntityDefaultUnitName(
        entityType: 'product',
        entityId: 42,
        ingredientId: 7,
        request: fake.call,
      );

      expect(name, '箱');
      // 商品自己有默认单位时不再查原料
      expect(fake.calls, ['/entities/product/42/units']);
    });

    test('商品没有默认单位时回退到关联原料的默认单位', () async {
      final fake = _FakeRequest({
        '/entities/product/42/units': [
          {'unit_name': '桶', 'is_default': false},
        ],
        '/entities/ingredient/7/units': [
          {'unit_name': '盒', 'is_default': true},
        ],
      });

      final name = await loadEntityDefaultUnitName(
        entityType: 'product',
        entityId: 42,
        ingredientId: 7,
        request: fake.call,
      );

      expect(name, '盒');
      expect(fake.calls, [
        '/entities/product/42/units',
        '/entities/ingredient/7/units',
      ]);
    });

    test('只认严格的 is_default=true，跳过停用行与空名字行', () async {
      final fake = _FakeRequest({
        '/entities/product/42/units': [
          {'unit_name': '停用默认', 'is_default': true, 'is_active': false},
          {'unit_name': '宽松真值', 'is_default': 1},
          {'unit_name': '缺字段'},
          {'unit_name': '  ', 'is_default': true},
          {'name': '袋', 'is_default': true},
        ],
      });

      final name = await loadEntityDefaultUnitName(
        entityType: 'product',
        entityId: 42,
        request: fake.call,
      );

      expect(name, '袋');
    });

    test('没有默认单位 → null（调用方保持原单位）', () async {
      final fake = _FakeRequest({
        '/entities/product/42/units': [
          {'unit_name': '桶', 'is_default': false},
        ],
        '/entities/ingredient/7/units': [
          {'unit_name': '盒'},
        ],
      });

      expect(
        await loadEntityDefaultUnitName(
          entityType: 'product',
          entityId: 42,
          ingredientId: 7,
          request: fake.call,
        ),
        isNull,
      );
    });

    test('请求失败 → null，不抛（不能因网络抖动改用户已选单位）', () async {
      final fake = _FakeRequest(
        const {},
        failures: {'/entities/product/42/units'},
      );

      expect(
        await loadEntityDefaultUnitName(
          entityType: 'product',
          entityId: 42,
          request: fake.call,
        ),
        isNull,
      );
    });
  });

  group('mergePriceUnitOptions', () {
    test('自定义单位排在全局单位前，且按名称去重', () {
      final merged = mergePriceUnitOptions(
        const ['桶', '斤'],
        const ['g', 'kg', '斤', '个'],
      );
      expect(merged, ['桶', '斤', 'g', 'kg', '个']);
    });

    test('空自定义单位只返回全局单位', () {
      expect(
        mergePriceUnitOptions(const [], const ['g', '个']),
        ['g', '个'],
      );
    });

    test('当前单位不在列表里时补到最前（避免下拉断言失败）', () {
      final merged = mergePriceUnitOptions(
        const ['桶'],
        const ['g', '个'],
        current: '已停用的单位',
      );
      expect(merged.first, '已停用的单位');
      expect(merged, contains('桶'));
    });

    test('当前单位已在列表里则不重复添加', () {
      final merged = mergePriceUnitOptions(
        const ['桶'],
        const ['g'],
        current: 'g',
      );
      expect(merged.where((u) => u == 'g').length, 1);
    });

    test('空白项被丢弃', () {
      expect(
        mergePriceUnitOptions(const ['  ', '桶'], const ['g', '']),
        ['桶', 'g'],
      );
    });
  });
}
