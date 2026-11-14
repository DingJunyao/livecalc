import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:com_a4ding_livecalc/features/merchants/repositories/merchant_repository.dart';
import 'package:com_a4ding_livecalc/features/merchants/services/region_matcher.dart';

class _MockRepo extends Mock implements MerchantRepository {}

Map<String, dynamic> _region(
  int id,
  String name, {
  String? iso,
  String? nameEn,
}) =>
    {
      'id': id,
      'name': name,
      if (iso != null) 'iso_country': iso,
      if (nameEn != null) 'name_en': nameEn,
    };

/// 测试区划树：
/// 中国(1)
/// ├── 北京市(10) → 东城区(101) / 西城区(102)          【直辖市扁平】
/// ├── 江苏省(20) → 南京市(200) → 玄武区(2001) / 鼓楼区(2002)
/// └── 直辖市乙(30) → 市辖区(300) → 城东区(301)        【市辖区单链穿透】
/// 美国(2) 无子级
void main() {
  late _MockRepo repo;

  final regionsByParent = <int?, List<Map<String, dynamic>>>{
    null: [
      _region(1, '中国', iso: 'CN', nameEn: 'China'),
      _region(2, '美国', iso: 'US', nameEn: 'United States'),
    ],
    1: [_region(10, '北京市'), _region(20, '江苏省'), _region(30, '直辖市乙')],
    10: [_region(101, '东城区'), _region(102, '西城区')],
    20: [_region(200, '南京市')],
    200: [_region(2001, '玄武区'), _region(2002, '鼓楼区')],
    30: [_region(300, '市辖区')],
    300: [_region(301, '城东区')],
  };

  setUp(() {
    repo = _MockRepo();
    when(() => repo.listRegions(
          parentId: any(named: 'parentId'),
          level: any(named: 'level'),
        )).thenAnswer((invocation) async {
      final parentId = invocation.namedArguments[#parentId] as int?;
      return regionsByParent[parentId] ?? <Map<String, dynamic>>[];
    });
  });

  test('标准省市县链全部命中', () async {
    final id = await matchRegionId(
      repo,
      countryCode: 'CN',
      administrativeArea: '江苏省',
      locality: '南京市',
      subLocality: '玄武区',
    );
    expect(id, 2001);
  });

  test('直辖市扁平层级（区挂在省级下）', () async {
    final id = await matchRegionId(
      repo,
      countryCode: 'CN',
      administrativeArea: '北京市',
      locality: '东城区',
    );
    expect(id, 101);
  });

  test('「市辖区」单链层级自动下穿', () async {
    final id = await matchRegionId(
      repo,
      countryCode: 'CN',
      administrativeArea: '直辖市乙',
      subLocality: '城东区',
    );
    expect(id, 301);
  });

  test('后缀剥离归一（江苏/南京/玄武）', () async {
    final id = await matchRegionId(
      repo,
      countryCode: 'CN',
      administrativeArea: '江苏',
      locality: '南京',
      subLocality: '玄武',
    );
    expect(id, 2001);
  });

  test('区县失配停在市级（最深命中）', () async {
    final id = await matchRegionId(
      repo,
      countryCode: 'CN',
      administrativeArea: '江苏省',
      locality: '南京市',
      subLocality: '不存在的区',
    );
    expect(id, 200);
  });

  test('国家按 iso_country 匹配，优先于名称', () async {
    final id = await matchRegionId(
      repo,
      countryCode: 'CN',
      country: 'United States',
      administrativeArea: '北京市',
      locality: '东城区',
    );
    expect(id, 101);
  });

  test('无 countryCode 时按 country 的中/英文名兜底', () async {
    final id = await matchRegionId(
      repo,
      country: 'China',
      administrativeArea: '北京市',
      locality: '东城区',
    );
    expect(id, 101);
  });

  test('非 CN 国家只有国家级命中（国际区划无子级）', () async {
    final id = await matchRegionId(
      repo,
      countryCode: 'US',
      administrativeArea: 'New York',
    );
    expect(id, 2);
  });

  test('无国家锚返回 null', () async {
    final id = await matchRegionId(
      repo,
      administrativeArea: '江苏省',
      locality: '南京市',
    );
    expect(id, isNull);
  });

  test('区划候选全空返回 null', () async {
    final id = await matchRegionId(repo, countryCode: 'CN');
    expect(id, isNull);
  });

  test('接口异常返回 null（best-effort 不抛）', () async {
    when(() => repo.listRegions(
          parentId: any(named: 'parentId'),
          level: any(named: 'level'),
        )).thenThrow(Exception('network'));
    final id = await matchRegionId(
      repo,
      countryCode: 'CN',
      administrativeArea: '江苏省',
    );
    expect(id, isNull);
  });
}
