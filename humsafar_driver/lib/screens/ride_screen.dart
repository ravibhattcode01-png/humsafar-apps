import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../services/api.dart';
import '../services/geo_service.dart';
import 'package:url_launcher/url_launcher.dart';

class RideScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  const RideScreen({super.key, required this.ride});
  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  final _map = MapController();
  late Map<String, dynamic> _ride;
  String _status = 'accepted';
  List<LatLng> _routePoints = [];
  LatLng? _myPos;
  Timer? _gpsTimer;
  bool _busy = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
    _status = _ride['status'] as String? ?? 'accepted';
    _loadRoute();
    _gpsTimer = Timer.periodic(const Duration(seconds: 8), (_) => _ping());
    _ping();
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    super.dispose();
  }

  LatLng _latLng(dynamic lat, dynamic lng) =>
      LatLng(double.parse(lat.toString()), double.parse(lng.toString()));

  LatLng get _pickup => _latLng(_ride['pickup_lat'], _ride['pickup_lng']);
  LatLng get _drop => _latLng(_ride['drop_lat'], _ride['drop_lng']);

  /// Status ke hisaab se route:
  /// accepted -> meri location se pickup tak
  /// ongoing  -> pickup se drop tak
  Future<void> _loadRoute() async {
    LatLng from;
    LatLng to;
    if (_status == 'ongoing') {
      from = _pickup;
      to = _drop;
    } else {
      from = _myPos ?? _pickup;
      to = _pickup;
      if (_myPos == null) {
        // Pehle apni location le lo
        try {
          final pos = await Geolocator.getCurrentPosition();
          from = LatLng(pos.latitude, pos.longitude);
          _myPos = from;
        } catch (_) {
          from = _pickup;
        }
      }
      if (_status == 'ongoing') to = _drop;
    }
    final route = await GeoService.route(from, to);
    if (!mounted) return;
    setState(() => _routePoints = route?.points ?? [from, to]);
    _map.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(
            [..._routePoints, _pickup, _drop]),
        padding: const EdgeInsets.fromLTRB(40, 100, 40, 300)));
  }

  Future<void> _ping() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      _myPos = LatLng(pos.latitude, pos.longitude);
      if (mounted) setState(() {});
      await Api.I.pingLocation(pos.latitude, pos.longitude,
          rideId: _ride['id'] as int);
    } catch (_) {}
  }

  Future<void> _arrived() async {
    setState(() => _busy = true);
    try {
      await Api.I.arrived(_ride['id'] as int);
      setState(() => _status = 'arrived');
    } catch (e) {
      _snack(e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _start() async {
    final otp = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rider se OTP poochein'),
        content: TextField(
          controller: otp,
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, letterSpacing: 10),
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ride Shuru Karein')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await Api.I.startRide(_ride['id'] as int, otp.text.trim());
      setState(() => _status = 'ongoing');
      _loadRoute(); // ab pickup->drop route dikhao
    } catch (e) {
      _snack(e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      final data = await Api.I.completeRide(_ride['id'] as int);
      setState(() {
        _status = 'completed';
        _result = data;
      });
      _gpsTimer?.cancel();
    } catch (e) {
      _snack(e.toString());
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _callRider() async {
    final phone = (_ride['user'] as Map<String, dynamic>?)?['phone']?.toString();
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    const green = Color(AppConfig.brandGreen);
    final user = _ride['user'] as Map<String, dynamic>?;

    return PopScope(
      canPop: _status == 'completed',
      child: Scaffold(
        body: Stack(children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: _pickup, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'app.humsafar.driver',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(
                      points: _routePoints, strokeWidth: 6, color: green),
                  Polyline(
                      points: _routePoints,
                      strokeWidth: 2.5,
                      color: Colors.white.withOpacity(0.7)),
                ]),
              MarkerLayer(markers: [
                Marker(
                    point: _pickup,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.trip_origin,
                        color: green, size: 26)),
                Marker(
                    point: _drop,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.location_on,
                        color: Colors.red, size: 36)),
                if (_myPos != null)
                  Marker(
                    point: _myPos!,
                    width: 46,
                    height: 46,
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                                blurRadius: 6, color: Colors.black26)
                          ]),
                      child: const Icon(Icons.two_wheeler,
                          color: Colors.black87, size: 28),
                    ),
                  ),
              ]),
            ],
          ),

          // Top status chip
          SafeArea(
            child: Center(
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _status == 'ongoing' ? green : Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  switch (_status) {
                    'accepted' => '🏍️ Pickup ki taraf jayein',
                    'arrived' => '📍 Pickup par — OTP lein',
                    'ongoing' => '🛣️ Ride chal rahi hai',
                    'completed' => '✅ Complete',
                    _ => _status,
                  },
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),

          // Bottom card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(blurRadius: 14, color: Colors.black26)
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      const CircleAvatar(
                          radius: 22, child: Icon(Icons.person)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user?['name']?.toString() ?? 'Rider',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              Text('📞 ${user?['phone'] ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54)),
                            ]),
                      ),
                      IconButton(
                        onPressed: _callRider,
                        icon: const Icon(Icons.call, color: green),
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: green)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                          '₹${((_ride['estimated_fare']) as num).round()}',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: green)),
                    ]),
                    const SizedBox(height: 8),
                    _addrRow(Icons.trip_origin, green,
                        _ride['pickup_address'] as String),
                    _addrRow(Icons.location_on, Colors.red,
                        _ride['drop_address'] as String),
                    const SizedBox(height: 12),
                    if (_status == 'completed' && _result != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14)),
                        child: Column(children: [
                          const Icon(Icons.check_circle,
                              color: green, size: 44),
                          const SizedBox(height: 8),
                          Text(
                              'Ride Complete! Kamai: ₹${_result!['your_earning']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Home par jayein')),
                        ]),
                      )
                    else if (_status == 'accepted')
                      ElevatedButton(
                          onPressed: _busy ? null : _arrived,
                          child: const Text('📍 Pickup Par Pahunch Gaya'))
                    else if (_status == 'arrived')
                      ElevatedButton(
                          onPressed: _busy ? null : _start,
                          child:
                              const Text('🔑 OTP Daalein & Ride Shuru'))
                    else if (_status == 'ongoing')
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: _busy ? null : _complete,
                        child: const Text('🏁 Ride Complete Karein'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _addrRow(IconData icon, Color color, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13))),
        ]),
      );
}
