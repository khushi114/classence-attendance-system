import 'dart:math';

/// Utility functions for geolocation calculations.
class GeoUtils {
  /// Earth's radius in meters (mean radius)
  static const double earthRadiusMeters = 6371000;

  /// Calculate the distance between two GPS coordinates using the Haversine formula.
  ///
  /// Returns the distance in meters.
  ///
  /// Formula reference: https://en.wikipedia.org/wiki/Haversine_formula
  static double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    // Convert degrees to radians
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  /// Convert degrees to radians.
  static double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  /// Format distance for display.
  ///
  /// Returns a human-readable string like "25.3 m" or "1.2 km"
  static String formatDistance(double distanceMeters) {
    if (distanceMeters < 1000) {
      return '${distanceMeters.toStringAsFixed(1)} m';
    } else {
      final km = distanceMeters / 1000;
      return '${km.toStringAsFixed(2)} km';
    }
  }

  /// Check if a point is within a circular geofence.
  ///
  /// Returns true if the distance between the two points is less than or equal to the radius.
  static bool isWithinRadius({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
    required double radiusMeters,
  }) {
    final distance = calculateDistance(
      lat1: lat1,
      lon1: lon1,
      lat2: lat2,
      lon2: lon2,
    );
    return distance <= radiusMeters;
  }
}
