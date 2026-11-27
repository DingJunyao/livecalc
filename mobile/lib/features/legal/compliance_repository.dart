import '../../../core/api/api_client.dart';

/// 公开启动配置（`GET /api/v1/app/config`）的本地模型。
///
/// 只包含「展示用」信息：注册策略、AI/地图的合规展示字段、法律文档元信息。
/// 任何密钥都不会出现在这个响应里。
class AiProviderInfo {
  final String key;
  final String displayName;
  final String modelName;
  final String filingNo;
  final String note;

  const AiProviderInfo({
    required this.key,
    required this.displayName,
    this.modelName = '',
    this.filingNo = '',
    this.note = '',
  });

  factory AiProviderInfo.fromJson(Map<String, dynamic> json) {
    return AiProviderInfo(
      key: '${json['key'] ?? ''}',
      displayName: '${json['display_name'] ?? json['key'] ?? ''}',
      modelName: '${json['model_name'] ?? ''}',
      filingNo: '${json['filing_no'] ?? ''}',
      note: '${json['note'] ?? ''}',
    );
  }
}

class MapProviderInfo {
  final String key;
  final String displayName;
  final String approvalNo;
  final String note;

  const MapProviderInfo({
    required this.key,
    required this.displayName,
    this.approvalNo = '',
    this.note = '',
  });

  factory MapProviderInfo.fromJson(Map<String, dynamic> json) {
    return MapProviderInfo(
      key: '${json['key'] ?? ''}',
      displayName: '${json['display_name'] ?? json['key'] ?? ''}',
      approvalNo: '${json['approval_no'] ?? ''}',
      note: '${json['note'] ?? ''}',
    );
  }
}

class AppComplianceConfig {
  final bool requireInviteCode;
  final bool aiEnabled;
  final List<AiProviderInfo> aiProviders;
  final bool mapEnabled;
  final List<MapProviderInfo> mapProviders;
  final String contactEmail;
  final String legalUpdatedAt;

  const AppComplianceConfig({
    this.requireInviteCode = false,
    this.aiEnabled = false,
    this.aiProviders = const [],
    this.mapEnabled = false,
    this.mapProviders = const [],
    this.contactEmail = '',
    this.legalUpdatedAt = '',
  });

  factory AppComplianceConfig.fromJson(Map<String, dynamic> json) {
    final ai = (json['ai'] as Map?)?.cast<String, dynamic>() ?? const {};
    final map = (json['map'] as Map?)?.cast<String, dynamic>() ?? const {};
    final legal = (json['legal'] as Map?)?.cast<String, dynamic>() ?? const {};
    List<T> list<T>(dynamic raw, T Function(Map<String, dynamic>) build) {
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => build(e.cast<String, dynamic>()))
          .toList(growable: false);
    }

    return AppComplianceConfig(
      requireInviteCode: json['registration_require_invite_code'] == true,
      aiEnabled: ai['enabled'] == true,
      aiProviders: list(ai['providers'], AiProviderInfo.fromJson),
      mapEnabled: map['enabled'] == true,
      mapProviders: list(map['providers'], MapProviderInfo.fromJson),
      contactEmail: '${legal['contact_email'] ?? ''}',
      legalUpdatedAt: '${legal['updated_at'] ?? ''}',
    );
  }
}

/// 公开配置与法律文档读取。
///
/// 服务器地址未配置（例如首次启动/服务器不可达）时返回 null，
/// 调用方回退到随包分发的默认法律文档。
class ComplianceRepository {
  Future<AppComplianceConfig?> fetchAppConfig() async {
    if (ApiClient.instance.baseUrl.isEmpty) return null;
    try {
      final resp = await ApiClient.instance.dio.get('/app/config');
      final data = resp.data;
      if (data is! Map) return null;
      return AppComplianceConfig.fromJson(data.cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  /// 返回服务器上的法律文档正文；不可用时返回 null（由调用方回退到内置文案）。
  Future<String?> fetchLegalDocument({
    required String doc,
    required String locale,
  }) async {
    if (ApiClient.instance.baseUrl.isEmpty) return null;
    try {
      final resp = await ApiClient.instance.dio.get(
        '/legal/$doc',
        queryParameters: {'locale': locale},
      );
      final data = resp.data;
      if (data is! Map) return null;
      final content = data['content'];
      if (content is String && content.trim().isNotEmpty) return content;
      return null;
    } catch (_) {
      return null;
    }
  }
}
