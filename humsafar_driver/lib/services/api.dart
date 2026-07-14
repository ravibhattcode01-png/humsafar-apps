import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

/// Driver app ka single API client (Sanctum bearer token).
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
    final res =
        await http.get(Uri.parse('${AppConfig.apiUrl}$path'), headers: _headers);
    return _decode(res);
  }

  Future<Map<String, dynamic>> post(String path,
      [Map<String, dynamic>? body]) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiUrl}$path'),
      headers: _headers,
      body: jsonEncode(body ?? {}),
    );
    return _decode(res);
  }

  /// Multipart POST — KYC document upload ke liye.
  Future<Map<String, dynamic>> postMultipart(
      String path, Map<String, String> fields,
      {Map<String, String> files = const {}}) async {
    final req =
        http.MultipartRequest('POST', Uri.parse('${AppConfig.apiUrl}$path'));
    req.headers['Accept'] = 'application/json';
    if (_token != null) req.headers['Authorization'] = 'Bearer $_token';
    req.fields.addAll(fields);
    for (final e in files.entries) {
      req.files.add(await http.MultipartFile.fromPath(e.key, e.value));
    }
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    final Map<String, dynamic> data =
        res.body.isNotEmpty ? jsonDecode(res.body) as Map<String, dynamic> : {};
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    String msg =
        data['message']?.toString() ?? 'Kuch galat ho gaya (${res.statusCode})';
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
      post('/auth/send-otp', {'phone': phone, 'role': 'driver'});

  Future<Map<String, dynamic>> verifyOtp(String phone, String otp,
      {String? name}) async {
    final data = await post('/auth/verify-otp', {
      'phone': phone,
      'otp': otp,
      'role': 'driver',
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

  // ---------- Driver ----------
  Future<Map<String, dynamic>> profile() => get('/driver/profile');

  Future<Map<String, dynamic>> register(Map<String, String> fields,
          {Map<String, String> files = const {}}) =>
      postMultipart('/driver/register', fields, files: files);

  Future<void> setOnline(bool online, {double? lat, double? lng}) =>
      post('/driver/status', {
        'is_online': online,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      });

  Future<void> pingLocation(double lat, double lng, {int? rideId}) =>
      post('/driver/location',
          {'lat': lat, 'lng': lng, if (rideId != null) 'ride_id': rideId});

  Future<Map<String, dynamic>> availableRides() =>
      get('/driver/rides/available');

  Future<Map<String, dynamic>> acceptRide(int rideId) =>
      post('/driver/rides/$rideId/accept');

  Future<void> arrived(int rideId) => post('/driver/rides/$rideId/arrived');

  Future<void> startRide(int rideId, String otp) =>
      post('/driver/rides/$rideId/start', {'otp': otp});

  Future<Map<String, dynamic>> completeRide(int rideId) =>
      post('/driver/rides/$rideId/complete');

  Future<Map<String, dynamic>> earnings() => get('/driver/earnings');

  Future<Map<String, dynamic>> wallet() => get('/wallet');

  Future<Map<String, dynamic>> incentives() => get('/driver/incentives');

  Future<Map<String, dynamic>> referral() => get('/referral');

  Future<Map<String, dynamic>> applyReferral(String code) =>
      post('/referral/apply', {'code': code});

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
