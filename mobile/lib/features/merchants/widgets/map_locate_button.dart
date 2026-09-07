import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../l10n/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _toast(l10n.mapLocationServiceDisabled);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _toast(l10n.mapLocationPermissionDeniedForever);
        return;
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        _toast(l10n.mapLocationPermissionDenied);
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
      _toast(l10n.mapLocationTimeout);
    } catch (_) {
      _toast(l10n.mapLocationFailed);
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
    final l10n = AppLocalizations.of(context);
    return IconButton(
      key: const ValueKey('map-locate-button'),
      tooltip: l10n.mapLocateAndChoose,
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
