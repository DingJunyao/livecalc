import '../../../core/api/api_client.dart';
import '../models/price_record.dart';

/// Result of a paginated price-records query.
class PriceRecordsResult {
  final List<PriceRecord> records;
  final int total;

  const PriceRecordsResult({required this.records, this.total = 0});
}

class PriceRepository {
  final ApiClient _client;
  ApiClient get client => _client;
  PriceRepository({ApiClient? client}) : _client = client ?? ApiClient.instance;

  /// 获取价格记录列表。
  /// 后端 GET /products 使用 skip/limit 分页，支持 search / merchant_ids /
  /// record_types / start_date / end_date 筛选。
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
    final skip = (page - 1) * pageSize;
    final params = <String, dynamic>{
      'skip': skip,
      'limit': limit ?? pageSize,
    };
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (merchantId != null) params['merchant_ids'] = merchantId.toString();
    if (ingredientId != null) params['ingredient_id'] = ingredientId.toString();
    if (productId != null) params['product_id'] = productId.toString();
    if (recordTypes != null) params['record_types'] = recordTypes;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;

    final response =
        await _client.dio.get('/products', queryParameters: params);
    final data = response.data;
    List<dynamic> list;
    int total;
    if (data is List) {
      list = data;
      total = data.length;
    } else {
      list = (data['items'] as List?) ?? [];
      total = (data['total'] as num?)?.toInt() ?? 0;
    }
    final records = list
        .map((e) => PriceRecord.fromJson(e as Map<String, dynamic>))
        .toList();
    return PriceRecordsResult(records: records, total: total);
  }

  /// 新建价格记录。
  Future<PriceRecord> createRecord({
    int? productId,
    String? productName,
    required double price,
    double quantity = 1,
    String unit = '个',
    int? merchantId,
    int? ingredientId,
    String recordType = 'purchase',
    String? notes,
    DateTime? recordedAt,
  }) async {
    final data = <String, dynamic>{
      'price': price,
      'original_quantity': quantity,
      'original_unit': unit,
      'record_type': recordType,
    };
    if (productId != null) {
      data['product_id'] = productId;
    } else if (productName != null && productName.isNotEmpty) {
      data['product_name'] = productName;
    }
    if (merchantId != null) data['merchant_id'] = merchantId;
    if (ingredientId != null) data['ingredient_id'] = ingredientId;
    if (notes != null) data['notes'] = notes;
    if (recordedAt != null) {
      data['recorded_at'] = recordedAt.toUtc().toIso8601String();
    }

    final response = await _client.dio.post('/products', data: data);
    return PriceRecord.fromJson(response.data as Map<String, dynamic>);
  }

  /// 更新价格记录（PUT /products/{id}）。
  Future<void> updateRecord(
    int id, {
    required double price,
    required double quantity,
    required String unit,
    int? merchantId,
  }) async {
    final data = <String, dynamic>{
      'price': price,
      'original_quantity': quantity,
      'original_unit': unit,
    };
    if (merchantId != null) data['merchant_id'] = merchantId;
    await _client.dio.put('/products/$id', data: data);
  }

  Future<void> deleteRecord(int id) async {
    await _client.dio.delete('/products/$id');
  }

  /// 粘贴导入时给商品加别名（POST /products/entity/{id}/add-import-alias）。
  /// body 仅含 {name}，后端会去重并忽略主名重复。
  Future<void> addImportAlias(int productId, String name) async {
    await _client.dio.post(
      '/products/entity/$productId/add-import-alias',
      data: {'name': name},
    );
  }
}
