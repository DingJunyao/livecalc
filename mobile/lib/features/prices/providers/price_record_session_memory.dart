import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 新增价格记录时「会话级」记住的选择（对齐 web 端 sessionStorage）：
/// 商家、是否计入支出。App 运行期间保持，下次打开新增价格记录表单时复用。
class PriceRecordSessionMemory {
  final int? merchantId;
  final bool isPurchase;

  const PriceRecordSessionMemory({this.merchantId, this.isPurchase = true});
}

class PriceRecordSessionMemoryNotifier extends Notifier<PriceRecordSessionMemory> {
  @override
  PriceRecordSessionMemory build() => const PriceRecordSessionMemory();

  /// 保存本次新增时使用的商家与计入支出选择。
  void save({int? merchantId, required bool isPurchase}) {
    state = PriceRecordSessionMemory(
      merchantId: merchantId,
      isPurchase: isPurchase,
    );
  }
}

final priceRecordSessionMemoryProvider =
    NotifierProvider<PriceRecordSessionMemoryNotifier, PriceRecordSessionMemory>(
  PriceRecordSessionMemoryNotifier.new,
);
