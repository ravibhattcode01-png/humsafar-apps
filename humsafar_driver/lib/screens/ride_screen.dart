import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../services/api.dart';

class RideScreen extends StatefulWidget {
  final Map<String, dynamic> ride;
  const RideScreen({super.key, required this.ride});
  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  late Map<String, dynamic> _ride;
  String _status = 'accepted';
  Timer? _gpsTimer;
  bool _busy = false;
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _ride = widget.ride;
    _status = _ride['status'] as String? ?? 'accepted';
    // Ride ke dauran GPS ping har 8 second (rider ko live tracking)
    _gpsTimer = Timer.periodic(const Duration(seconds: 8), (_) => _ping());
    _ping();
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    super.dispose();
  }

  Future<void> _ping() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
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
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8),
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

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    const green = Color(AppConfig.brandGreen);
    final user = _ride['user'] as Map<String, dynamic>?;
    final pickup = LatLng(double.parse(_ride['pickup_lat'].toString()),
        double.parse(_ride['pickup_lng'].toString()));
    final drop = LatLng(double.parse(_ride['drop_lat'].toString()),
        double.parse(_ride['drop_lng'].toString()));

    return PopScope(
      canPop: _status == 'completed',
      child: Scaffold(
        appBar: AppBar(
            title: Text(_ride['ride_code'] as String? ?? 'Active Ride'),
            automaticallyImplyLeading: _status == 'completed'),
        body: Column(children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(initialCenter: pickup, initialZoom: 14),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'app.humsafar.driver',
                ),
                PolylineLayer(polylines: [
                  Polyline(
                      points: [pickup, drop],
                      strokeWidth: 3,
                      color: green.withOpacity(0.6)),
                ]),
                MarkerLayer(markers: [
                  Marker(
                      point: pickup,
                      width: 36,
                      height: 36,
                      child: const Icon(Icons.trip_origin,
                          color: green, size: 28)),
                  Marker(
                      point: drop,
                      width: 36,
                      height: 36,
                      child: const Icon(Icons.location_on,
                          color: Colors.red, size: 32)),
                ]),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black12)],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Rider info
                  Row(children: [
                    const CircleAvatar(child: Icon(Icons.person)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?['name']?.toString() ?? 'Rider',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(user?['phone']?.toString() ?? '',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54)),
                          ]),
                    ),
                    Text('₹${_ride['estimated_fare']}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: green)),
                  ]),
                  const SizedBox(height: 8),
                  Text('📍 ${_ride['pickup_address']}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('🏁 ${_ride['drop_address']}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 12),

                  if (_status == 'completed' && _result != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        const Icon(Icons.check_circle, color: green, size: 40),
                        const SizedBox(height: 8),
                        Text(
                            'Ride Complete! Aapki kamai: ₹${_result!['your_earning']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Home par jayein')),
                      ]),
                    )
                  else if (_status == 'accepted')
                    ElevatedButton(
                      onPressed: _busy ? null : _arrived,
                      child: const Text('Pickup Par Pahunch Gaya'),
                    )
                  else if (_status == 'arrived')
                    ElevatedButton(
                      onPressed: _busy ? null : _start,
                      child: const Text('OTP Daalein & Ride Shuru Karein'),
                    )
                  else if (_status == 'ongoing')
                    ElevatedButton(
                      style:
                          ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: _busy ? null : _complete,
                      child: const Text('Ride Complete Karein'),
                    ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
