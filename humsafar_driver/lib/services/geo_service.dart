import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Free geo services — koi API key nahi chahiye.
/// - Nominatim (OpenStreetMap): address search + reverse geocoding
/// - OSRM: road-following route polyline
class GeoService {
  static const _ua = {'User-Agent': 'HumsafarApp/1.0 (contact@ngie.in)'};

  /// Jagah ka naam -> suggestions (India-biased).
  static Future<List<PlaceResult>> search(String query,
      {LatLng? near}) async {
    if (query.trim().length < 3) return [];
    final params = {
      'q': query,
      'format': 'json',
      'countrycodes': 'in',
      'limit': '6',
      'addressdetails': '1',
      if (near != null)
        'viewbox':
            '${near.longitude - 0.3},${near.latitude + 0.3},${near.longitude + 0.3},${near.latitude - 0.3}',
      if (near != null) 'bounded': '0',
    };
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);
    try {
      final res = await http.get(uri, headers: _ua);
      if (res.statusCode != 200) return [];
      final list = jsonDecode(res.body) as List<dynamic>;
      return list
          .map((e) => PlaceResult(
                name: _shortName(e),
                address: e['display_name'] as String? ?? '',
                point: LatLng(double.parse(e['lat'] as String),
                    double.parse(e['lon'] as String)),
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String _shortName(dynamic e) {
    final a = e['address'] as Map<String, dynamic>? ?? {};
    return (e['name'] as String?)?.isNotEmpty == true
        ? e['name'] as String
        : (a['road'] ?? a['suburb'] ?? a['city'] ?? a['town'] ??
                a['village'] ?? e['display_name'] ?? '')
            .toString();
  }

  /// Coordinates -> readable address.
  static Future<String> reverseGeocode(LatLng p) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': p.latitude.toString(),
      'lon': p.longitude.toString(),
      'format': 'json',
      'zoom': '17',
    });
    try {
      final res = await http.get(uri, headers: _ua);
      if (res.statusCode != 200) return _fallback(p);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final a = data['address'] as Map<String, dynamic>? ?? {};
      final parts = [
        a['amenity'] ?? a['shop'] ?? a['building'],
        a['road'],
        a['suburb'] ?? a['neighbourhood'],
        a['city'] ?? a['town'] ?? a['village'],
      ].where((x) => x != null).map((x) => x.toString()).toList();
      return parts.isEmpty ? _fallback(p) : parts.take(3).join(', ');
    } catch (_) {
      return _fallback(p);
    }
  }

  static String _fallback(LatLng p) =>
      '${p.latitude.toStringAsFixed(4)}, ${p.longitude.toStringAsFixed(4)}';

  /// Road route between two points (OSRM public server).
  /// Returns polyline points + distance km + duration min.
  static Future<RouteResult?> route(LatLng from, LatLng to) async {
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/${from.longitude},${from.latitude};${to.longitude},${to.latitude}',
      {'overview': 'full', 'geometries': 'geojson'},
    );
    try {
      final res = await http.get(uri, headers: _ua);
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;
      final r = routes.first as Map<String, dynamic>;
      final coords =
          (r['geometry']['coordinates'] as List<dynamic>).map((c) {
        final l = c as List<dynamic>;
        return LatLng((l[1] as num).toDouble(), (l[0] as num).toDouble());
      }).toList();
      return RouteResult(
        points: coords,
        distanceKm: (r['distance'] as num).toDouble() / 1000,
        durationMin: (r['duration'] as num).toDouble() / 60,
      );
    } catch (_) {
      return null;
    }
  }
}

class PlaceResult {
  final String name;
  final String address;
  final LatLng point;
  PlaceResult({required this.name, required this.address, required this.point});
}

class RouteResult {
  final List<LatLng> points;
  final double distanceKm;
  final double durationMin;
  RouteResult(
      {required this.points,
      required this.distanceKm,
      required this.durationMin});
}
