import '../../domain/entities/entities.dart';

/// Utility class for decoding Google Encoded Polylines into coordinate lists.
class PolylineUtils {
  const PolylineUtils._();

  /// Decode a Google Encoded Polyline string into a list of [LatLngPoint].
  static List<LatLngPoint> decodePolyline(String encoded) {
    if (encoded.isEmpty) return const [];

    final points = <LatLngPoint>[];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < len);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      if (index >= len) break;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20 && index < len);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLngPoint(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}
