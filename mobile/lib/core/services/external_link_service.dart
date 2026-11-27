import 'package:flutter/services.dart';

/// 打开外部链接（项目主页/作者主页）。
///
/// 用原生通道而不是 url_launcher 插件：本机（以及部分国内网络）访问 GitHub 时会
/// 超时，新增 SPM 依赖会让 iOS 构建卡在拉包阶段。这里复用两端已有的原生桥接
/// 方式（AppShortcutsPlugin / MainActivity），不引入第三方插件。
class ExternalLinkService {
  static const _channel =
      MethodChannel('com.a4ding.livecalc/external_url');

  /// 返回是否成功唤起浏览器/邮件等外部应用。
  static Future<bool> open(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return false;
    try {
      final ok = await _channel.invokeMethod<bool>(
        'openUrl',
        {'url': trimmed},
      );
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }
}
