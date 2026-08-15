import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

/// Requests the current device position and reports it in WGS84.
class MapLocateButton extends StatefulWidget {
  final ValueChanged<LatLng> onLocated;

  const MapLocateButton({
    super.key,
    required this.onLocated,
  });

  @override
  State<MapLocateButton> createState() => _MapLocateButtonState();
}

class _MapLocateButtonState extends State<MapLocateButton> {
  bool _locating = false;

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _toast('定位服务未开启，请在系统设置中打开');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _toast('位置权限已被永久拒绝，请到系统设置中开启');
        return;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        _toast('位置权限被拒绝');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      widget.onLocated(LatLng(position.latitude, position.longitude));
    } on TimeoutException {
      _toast('定位超时，请重试');
    } catch (_) {
      _toast('定位失败，请重试');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('map-locate-button'),
      tooltip: '定位并选择当前位置',
      icon: _locating
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.my_location_outlined, size: 20),
      onPressed: _locating ? null : _locate,
    );
  }
}
