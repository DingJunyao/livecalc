import 'package:flutter_test/flutter_test.dart';
import 'package:com_a4ding_livecalc/features/prices/models/price_record.dart';
import 'package:com_a4ding_livecalc/features/prices/providers/price_provider.dart';
import 'package:com_a4ding_livecalc/features/prices/repositories/price_repository.dart';

/// 可记录 updateRecord / deleteRecord 调用参数，并可控失败。
class _FakePriceRepository extends PriceRepository {
  _FakePriceRepository(this._seed);

  final List<PriceRecord> _seed;
  List<PriceRecord> get seed => _seed;

  int getRecordsCalls = 0;
  int updateCalls = 0;
  int? lastUpdateId;
  double? lastUpdatePrice;
  double? lastUpdateQuantity;
  String? lastUpdateUnit;
  int? lastUpdateMerchantId;
  String? lastUpdateRecordType;
  DateTime? lastUpdateRecordedAt;
  String? lastUpdateNotes;
  Exception? updateError;

  int deleteCalls = 0;
  int? lastDeleteId;
  Exception? deleteError;

  @override
  Future<PriceRecordsResult> getRecords({
    String? search,
    int? merchantId,
    int? ingredientId,
    int? productId,
    String? recordTypes,
    String? startDate,
    String? endDate,
    int? limit,
    int page = 1,
    int pageSize = 20,
  }) async {
    getRecordsCalls++;
    return PriceRecordsResult(records: _seed, total: _seed.length);
  }

  @override
  Future<void> updateRecord(
    int id, {
    required double price,
    required double quantity,
    required String unit,
    int? merchantId,
    String recordType = 'purchase',
    DateTime? recordedAt,
    String? notes,
  }) async {
    updateCalls++;
    lastUpdateId = id;
    lastUpdatePrice = price;
    lastUpdateQuantity = quantity;
    lastUpdateUnit = unit;
    lastUpdateMerchantId = merchantId;
    lastUpdateRecordType = recordType;
    lastUpdateRecordedAt = recordedAt;
    lastUpdateNotes = notes;
    if (updateError != null) throw updateError!;
  }

  @override
  Future<void> deleteRecord(int id) async {
    deleteCalls++;
    lastDeleteId = id;
    if (deleteError != null) throw deleteError!;
  }
}

PriceRecord _rec({
  int id = 1,
  int productId = 10,
  String productName = '番茄',
  double price = 6.88,
  double quantity = 500,
  String unit = 'g',
  int? merchantId = 1,
  String? merchantName = '盒马鲜生',
}) =>
    PriceRecord(
      id: id,
      productId: productId,
      productName: productName,
      price: price,
      quantity: quantity,
      unit: unit,
      merchantId: merchantId,
      merchantName: merchantName,
      recordedAt: '2026-08-11T10:00:00Z',
    );

void main() {
  late _FakePriceRepository repo;
  late PriceListNotifier notifier;

  setUp(() async {
    repo = _FakePriceRepository([_rec()]);
    notifier = PriceListNotifier(repo);
    await notifier.loadRecords();
  });

  group('updateRecord', () {
    test('成功：局部更新对应记录的 price/quantity/unit/merchantId/Name，return true',
        () async {
      const id = 1;
      const newPrice = 9.9;
      const newQty = 1000.0;
      const newUnit = 'kg';
      const newMerchantId = 2;

      final ok = await notifier.updateRecord(
        id,
        price: newPrice,
        quantity: newQty,
        unit: newUnit,
        merchantId: newMerchantId,
        merchantName: '超市',
      );

      expect(ok, isTrue);
      // repo 调用参数
      expect(repo.updateCalls, 1);
      expect(repo.lastUpdateId, id);
      expect(repo.lastUpdatePrice, newPrice);
      expect(repo.lastUpdateQuantity, newQty);
      expect(repo.lastUpdateUnit, newUnit);
      expect(repo.lastUpdateMerchantId, newMerchantId);

      // state 局部更新（未重新 loadRecords）
      final updated = notifier.state.records.firstWhere((r) => r.id == id);
      expect(updated.price, newPrice);
      expect(updated.quantity, newQty);
      expect(updated.unit, newUnit);
      expect(updated.merchantId, newMerchantId);
      // merchantName 由调用方反查传入，局部更新写入
      expect(updated.merchantName, '超市');
      // 记录条数不变
      expect(notifier.state.records.length, 1);
    });

    test('成功：merchantName 传 null 时（反查不到商家），局部更新后为 null', () async {
      final ok = await notifier.updateRecord(
        1,
        price: 1,
        quantity: 1,
        unit: 'g',
        merchantId: null,
        merchantName: null,
      );
      expect(ok, isTrue);
      expect(notifier.state.records.first.merchantName, isNull);
      expect(notifier.state.records.first.merchantId, isNull);
    });

    test('成功：不应触发 getRecords（避免丢滚动位置）', () async {
      final callsBefore = repo.getRecordsCalls;
      expect(notifier.state.records.length, 1);

      await notifier.updateRecord(
        1,
        price: 1,
        quantity: 1,
        unit: 'g',
        merchantId: null,
        merchantName: null,
      );

      expect(repo.getRecordsCalls, callsBefore); // 0 增量
      expect(notifier.state.records.length, 1);
    });

    test('失败（repo 抛异常）：return false，state.records 不变', () async {
      repo.updateError = Exception('网络错误');
      final beforeSnapshot =
          notifier.state.records.map((r) => r.price).toList();

      final ok = await notifier.updateRecord(
        1,
        price: 99.9,
        quantity: 99,
        unit: 'kg',
        merchantId: 2,
        merchantName: '新商家',
      );

      expect(ok, isFalse);
      expect(
          notifier.state.records.map((r) => r.price).toList(), beforeSnapshot);
    });
  });

  group('deleteRecord', () {
    test('成功：移除该 id 记录，total - 1，return true', () async {
      // 再加一条以避免删空
      repo.seed.add(_rec(id: 2, productName: '鸡蛋'));
      // 手动再 load 把第二条读进 state
      await notifier.loadRecords();
      expect(notifier.state.records.length, 2);
      expect(notifier.state.total, 2);

      final ok = await notifier.deleteRecord(1);

      expect(ok, isTrue);
      expect(repo.deleteCalls, 1);
      expect(repo.lastDeleteId, 1);
      expect(notifier.state.records.any((r) => r.id == 1), isFalse);
      expect(notifier.state.records.length, 1);
      expect(notifier.state.total, 1);
    });

    test('成功：不应触发 getRecords', () async {
      final callsBefore = repo.getRecordsCalls;
      await notifier.deleteRecord(1);
      expect(repo.getRecordsCalls, callsBefore); // 0 增量
    });

    test('成功：total 已为 0 时不变成负数', () async {
      // 删到空：seed 只有 1 条
      final ok = await notifier.deleteRecord(1);
      expect(ok, isTrue);
      expect(notifier.state.records, isEmpty);
      expect(notifier.state.total, 0);

      // 再删不存在的：不会让 total 为负
      final ok2 = await notifier.deleteRecord(999);
      expect(ok2, isTrue);
      expect(notifier.state.total, 0);
    });

    test('成功：删不存在的 id 时 records 和 total 都不变', () async {
      // 先确保 state 里只有 id=1 一条
      expect(notifier.state.records.length, 1);
      expect(notifier.state.total, 1);

      final ok = await notifier.deleteRecord(999);

      expect(ok, isTrue);
      expect(repo.deleteCalls, 1);
      expect(repo.lastDeleteId, 999);
      // records 与 total 完全不变
      expect(notifier.state.records.length, 1);
      expect(notifier.state.total, 1);
    });

    test('失败（repo 抛异常）：return false，state.records 不变', () async {
      repo.deleteError = Exception('删除失败');
      final beforeCount = notifier.state.records.length;
      final beforeTotal = notifier.state.total;

      final ok = await notifier.deleteRecord(1);

      expect(ok, isFalse);
      expect(notifier.state.records.length, beforeCount);
      expect(notifier.state.total, beforeTotal);
    });
  });
}
