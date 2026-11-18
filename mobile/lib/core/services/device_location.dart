import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// 静默获取当前设备位置（WGS84）。
///
/// 与地图选点组件里的主动定位按钮不同，这里服务于「可选的位置偏置」场景
/// （如苹果地图商家名称/地址匹配）：定位服务关闭、权限被拒、获取超时或
/// 任何异常一律返回 null，不弹提示，由调用方回退到原有逻辑。
Future<LatLng?> getCurrentLatLngSilently() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever ||
        permission == LocationPermission.unableToDetermine) {
      return null;
    }
    // 50km 搜索偏置对精度要求很低：低精度出结果更快，失败静默降级。
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 5),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  } catch (_) {
    return null;
  }
}
