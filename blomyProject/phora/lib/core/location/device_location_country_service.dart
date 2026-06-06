import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class DeviceCountrySignals {
  const DeviceCountrySignals({
    required this.billingCountry,
    this.deviceLocaleCountryCode,
    this.deviceLocationCountryCode,
  });

  final String billingCountry;
  final String? deviceLocaleCountryCode;
  final String? deviceLocationCountryCode;
}

class DeviceLocationCountryService {
  Future<String?> deviceLocationCountryCode() async {
    if (kIsWeb) {
      return null;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.lowest,
          timeLimit: Duration(seconds: 8),
        ),
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 8));
      for (final placemark in placemarks) {
        final code = placemark.isoCountryCode?.trim().toUpperCase();
        if (code != null && code.length == 2) {
          return code;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String? deviceLocaleCountryCode() {
    final code = PlatformDispatcher.instance.locale.countryCode;
    if (code == null || code.trim().isEmpty) {
      return null;
    }
    return code.trim().toUpperCase();
  }
}
