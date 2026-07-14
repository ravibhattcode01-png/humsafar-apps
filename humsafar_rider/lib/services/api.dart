import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

/// Single API client for the whole app.
/// Token SharedPreferences me save hota hai aur har request me jata hai.
class Api {
  Api._();
  static final Api I = Api._();

  String? _token;

  Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    _token = sp.getString('token');
  }

  bool get isLoggedIn => _token != null;

  Future<void> saveToken(String token) async {
    _token = token;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('token', token);
  }

  Future<void> clearToken() async {
    _token = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove('token');
  }

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(Uri.parse('${AppConfig.apiUrl}$path'), headers: _headers);
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: _headers,
      body: jsonEncode(body ?? {}),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final res = await http.delete(Uri.parse('${AppConfig.apiUrl}$path'), headers: _headers);
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final Map<String, dynamic> data =
        res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic> : {};
    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    // Laravel validation errors -> readable message
    String msg = data['message']?.toString() ?? 'Kuch galat ho gaya (${res.statusCode})';
    if (data['errors'] is Map) {
      final errs = data['errors'] as Map;
      if (errs.isNotEmpty) {
        final first = errs.values.first;
        if (first is List && first.isNotEmpty) msg = first.first.toString();
      }
    }
    throw ApiException(msg, res.statusCode);
  }

  // ---------- Auth ----------
  Future<void> sendOtp(String phone) async =>
      post('/auth/send-otp', {'phone': phone, 'role': 'rider'});

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp, {String? name}) async {
    final data = await post('/auth/verify-otp', {
      'phone': phone,
      'otp': otp,
      'role': 'rider',
      if (name != null && name.isNotEmpty) 'name': name,
    });
    await saveToken(data['token'] as String);
    return data;
  }

  Future<void> logout() async {
    try {
      await post('/auth/logout');
    } catch (_) {}
    await clearToken();
  }

  // ---------- Bootstrap ----------
  Future<Map<String, dynamic>> bootstrap() => get('/bootstrap');

  // ---------- Rider ----------
  Future<Map<String, dynamic>> profile() => get('/rider/profile');

  Future<Map<String, dynamic>> estimateFare({
    required int cityId,
    required double pickupLat,
    required double pickupLng,
    required double dropLat,
    required double dropLng,
  }) =>
      post('/rider/estimate-fare', {
        'city_id': cityId,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        'drop_lat': dropLat,
        'drop_lng': dropLng,
      });

  Future<Map<String, dynamic>> bookRide(Map<String, dynamic> payload) =>
      post('/rider/rides', payload);

  Future<Map<String, dynamic>> rideStatus(int rideId) => get('/rider/rides/$rideId');

  Future<Map<String, dynamic>> history() => get('/rider/rides');

  Future<void> cancelRide(int rideId, String reason) =>
      post('/rider/rides/$rideId/cancel', {'reason': reason});

  Future<void> rateRide(int rideId, int rating, String comment) =>
      post('/rider/rides/$rideId/rate', {'rating': rating, 'comment': comment});

  Future<Map<String, dynamic>> wallet() => get('/wallet');

  Future<Map<String, dynamic>> validatePromo(String code, double fare) =>
      post('/rider/promo/validate', {'code': code, 'fare': fare});

  Future<Map<String, dynamic>> invoiceUrl(int rideId) =>
      get('/rider/rides/$rideId/invoice');

  Future<Map<String, dynamic>> referral() => get('/referral');

  Future<Map<String, dynamic>> applyReferral(String code) =>
      post('/referral/apply', {'code': code});

  Future<Map<String, dynamic>> favourites() => get('/rider/favourites');

  Future<Map<String, dynamic>> addFavourite(
          String label, String address, double lat, double lng) =>
      post('/rider/favourites',
          {'label': label, 'address': address, 'lat': lat, 'lng': lng});

  Future<void> deleteFavourite(int id) => delete('/rider/favourites/$id');

  Future<void> sos({int? rideId, double? lat, double? lng}) =>
      post('/sos', {'ride_id': rideId, 'lat': lat, 'lng': lng});
}

class ApiException implements Exception {
  final String message;
  final int status;
  ApiException(this.message, this.status);
  @override
  String toString() => message;
}
