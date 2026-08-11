import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/prices/utils/paste_price_parser.dart';

void main() {
  group('parsePasteLine - 四种合法格式', () {
    test('格式1：名 价格（默认 1 斤）', () {
      final r = parsePasteLine('芹菜 1.88');
      expect(r.ok, true);
      expect(r.name, '芹菜');
      expect(r.price, 1.88);
      expect(r.quantity, 1);
      expect(r.unit, '斤');
      expect(r.error, isNull);
      expect(r.raw, '芹菜 1.88');
    });

    test('格式2：名 价格/单位（1 单位）', () {
      final r = parsePasteLine('芽菇 4/袋');
      expect(r.ok, true);
      expect(r.name, '芽菇');
      expect(r.price, 4);
      expect(r.quantity, 1);
      expect(r.unit, '袋');
    });

    test('格式3：名 价格/缩写单位（1 kg）', () {
      final r = parsePasteLine('嫩豆腐 5.18/kg');
      expect(r.ok, true);
      expect(r.name, '嫩豆腐');
      expect(r.price, 5.18);
      expect(r.quantity, 1);
      expect(r.unit, 'kg');
    });

    test('格式4：名 价格/数量+单位（200 g）', () {
      final r = parsePasteLine('土豆粉 2.5/200g');
      expect(r.ok, true);
      expect(r.name, '土豆粉');
      expect(r.price, 2.5);
      expect(r.quantity, 200);
      expect(r.unit, 'g');
    });

    test('整数价格', () {
      final r = parsePasteLine('苹果 3');
      expect(r.ok, true);
      expect(r.price, 3);
    });

    test('名称带空格（非贪婪 + 最后一个空格后的数字作价）', () {
      final r = parsePasteLine('红富士 苹果 5.5');
      expect(r.ok, true);
      expect(r.name, '红富士 苹果');
      expect(r.price, 5.5);
    });
  });

  group('parsePasteLine - 单位别名', () {
    test('克 → g', () {
      expect(parsePasteLine('盐 1/100克').unit, 'g');
    });
    test('公斤 → kg', () {
      expect(parsePasteLine('米 10/1公斤').unit, 'kg');
    });
    test('千克 → kg', () {
      expect(parsePasteLine('米 10/1千克').unit, 'kg');
    });
    test('斤保持原样', () {
      expect(parsePasteLine('白菜 2/1斤').unit, '斤');
    });
    test('未知单位原样保留', () {
      expect(parsePasteLine('鸡蛋 12/打').unit, '打');
    });
  });

  group('parsePasteLine - 边界', () {
    test('空行', () {
      final r = parsePasteLine('');
      expect(r.ok, false);
      expect(r.error, '空行');
      expect(r.name, '');
    });

    test('仅空白', () {
      final r = parsePasteLine('   ');
      expect(r.ok, false);
      expect(r.error, '空行');
    });

    test('注释行（# 开头）', () {
      final r = parsePasteLine('# 这是注释');
      expect(r.ok, false);
      expect(r.error, '注释行');
    });

    test('注释行（# 前导空白）仍识别为注释', () {
      // trim 后 # 开头
      final r = parsePasteLine('  # 注释');
      expect(r.ok, false);
      expect(r.error, '注释行');
    });

    test('格式无法识别（无价格）', () {
      final r = parsePasteLine('只有名字');
      expect(r.ok, false);
      expect(r.error, '格式无法识别');
    });

    test('格式无法识别（价格非数字）', () {
      final r = parsePasteLine('番茄 abc');
      expect(r.ok, false);
      expect(r.error, '格式无法识别');
    });

    test('价格为 0 → 价格无效', () {
      final r = parsePasteLine('番茄 0');
      expect(r.ok, false);
      expect(r.error, '价格无效');
      expect(r.name, '番茄');
    });

    test('价格为负 → 不匹配（格式无法识别）', () {
      // 负号不在数字字符集内，正则不匹配
      final r = parsePasteLine('番茄 -3');
      expect(r.ok, false);
      expect(r.error, '格式无法识别');
    });
  });

  group('parsePasteLine - defaultUnit', () {
    test('未指定时默认斤', () {
      expect(parsePasteLine('盐 1').unit, '斤');
    });

    test('显式 defaultUnit 生效', () {
      expect(parsePasteLine('盐 1', defaultUnit: 'kg').unit, 'kg');
    });
  });

  group('parsePasteText - 多行', () {
    test('混合多行（合法 + 空行 + 注释 + 非法）', () {
      final lines = parsePasteText(
        '芹菜 1.88\n'
        '\n'
        '# 注释\n'
        '芽菇 4/袋\n'
        '坏数据',
      );
      expect(lines.length, 5);
      expect(lines[0].ok, true);
      expect(lines[0].name, '芹菜');
      expect(lines[1].ok, false);
      expect(lines[1].error, '空行');
      expect(lines[2].ok, false);
      expect(lines[2].error, '注释行');
      expect(lines[3].ok, true);
      expect(lines[3].unit, '袋');
      expect(lines[4].ok, false);
      expect(lines[4].error, '格式无法识别');
    });

    test('CRLF 换行也能拆', () {
      final lines = parsePasteText('芹菜 1.88\r\n芽菇 4/袋');
      expect(lines.length, 2);
      expect(lines[0].name, '芹菜');
      expect(lines[1].name, '芽菇');
    });

    test('空串拆出 1 行空行', () {
      final lines = parsePasteText('');
      expect(lines.length, 1);
      expect(lines.first.ok, false);
      expect(lines.first.error, '空行');
    });
  });
}
