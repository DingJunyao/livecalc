import 'package:flutter_test/flutter_test.dart';

import 'package:com_a4ding_livecalc/features/legal/compliance_repository.dart';

void main() {
  test('新版服务端：解析服务端版本与 apple 地图条目', () {
    final config = AppComplianceConfig.fromJson({
      'version': '0.9.1',
      'registration_require_invite_code': false,
      'ai': {'enabled': true, 'providers': []},
      'map': {
        'enabled': true,
        'default': 'amap',
        'providers': [
          {
            'key': 'amap',
            'display_name': '高德地图',
            'approval_no': 'GS(2024)0001号',
            'approval_no_satellite': 'GS(2024)0002号',
            'note': '',
          },
        ],
        'apple': {
          'key': 'apple',
          'display_name': 'Apple 地图',
          'approval_no': 'GS(2024)0003号',
          'approval_no_satellite': '',
          'note': '中国区数据由高德地图提供',
        },
      },
      'legal': {'contact_email': 'a@b.com', 'updated_at': '2026-11-28T00:00:00Z'},
    });

    expect(config.serverVersion, '0.9.1');
    expect(config.mapEnabled, isTrue);
    expect(config.mapProviders.single.approvalNo, 'GS(2024)0001号');
    expect(config.mapProviders.single.approvalNoSatellite, 'GS(2024)0002号');
    expect(config.appleMap, isNotNull);
    expect(config.appleMap!.approvalNo, 'GS(2024)0003号');
  });

  test('旧版服务端：缺少 version / map.apple 时降级为「未上报 + 无 apple 条目」', () {
    final config = AppComplianceConfig.fromJson({
      'registration_require_invite_code': false,
      'ai': {'enabled': false, 'providers': []},
      'map': {'enabled': true, 'default': 'amap', 'providers': []},
      'legal': {'contact_email': '', 'updated_at': ''},
    });

    // 页面据此提示「服务端版本较旧，请升级」，而不是显示空白
    expect(config.serverVersion, isEmpty);
    // iOS 页面会把 null 降级成默认的「Apple 地图」条目（审图号未填写）
    expect(config.appleMap, isNull);
  });
}
