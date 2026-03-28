import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OsrmService {
  static const String _baseUrl = 'http://router.project-osrm.org';

  // Get route between 2 points → returns list of LatLng
  static Future<List<LatLng>> getRoute(LatLng from, LatLng to) async {
    try {
      final url = '$_baseUrl/route/v1/driving/'
          '${from.longitude},${from.latitude};'
          '${to.longitude},${to.latitude}'
          '?overview=full&geometries=geojson';

      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return [from, to]; // fallback straight line

      final data = jsonDecode(res.body);
      final coords = data['routes'][0]['geometry']['coordinates'] as List;

      return coords.map((c) => LatLng(
        (c[1] as num).toDouble(),
        (c[0] as num).toDouble(),
      )).toList();
    } catch (e) {
      return [from, to]; // fallback straight line if OSRM fails
    }
  }

  // Get distance (km) and duration (min) between 2 points
  static Future<Map<String, double>> getDistanceAndDuration(
      LatLng from, LatLng to) async {
    try {
      final url = '$_baseUrl/route/v1/driving/'
          '${from.longitude},${from.latitude};'
          '${to.longitude},${to.latitude}'
          '?overview=false';

      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);
      final route = data['routes'][0];

      return {
        'distance': (route['distance'] as num).toDouble() / 1000, // meters → km
        'duration': (route['duration'] as num).toDouble() / 60,   // seconds → min
      };
    } catch (e) {
      return {'distance': 0.0, 'duration': 0.0};
    }
  }

  // Get route for multiple stops (VRP use case)
  static Future<List<LatLng>> getMultiStopRoute(List<LatLng> points) async {
    if (points.length < 2) return points;
    try {
      final coords = points
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');

      final url = '$_baseUrl/route/v1/driving/$coords'
          '?overview=full&geometries=geojson';

      final res = await http.get(Uri.parse(url));
      final data = jsonDecode(res.body);
      final coordsList = data['routes'][0]['geometry']['coordinates'] as List;

      return coordsList.map((c) => LatLng(
        (c[1] as num).toDouble(),
        (c[0] as num).toDouble(),
      )).toList();
    } catch (e) {
      return points;
    }
  }
}