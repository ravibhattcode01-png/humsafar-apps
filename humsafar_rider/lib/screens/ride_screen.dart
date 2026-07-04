import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../services/api.dart';

class RideScreen extends StatefulWidget {
  final int rideId;
  const RideScreen({super.key, required this.rideId});
  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  Map<String, dynamic>? _ride;
  Timer? _timer;
  bool _rated = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Live status polling har 5 second (production me WebSocket/Reverb)
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final data = await Api.I.rideStatus(widget.rideId);
      if (!mounted) return;
      setState(() => _ride = data['ride'] as Map<String, dynamic>);
      final st = _ride!['status'] as String;
      if (st == 'completed' || st == 'cancelled') _timer?.cancel();
    } catch (_) {}
  }

  Future<void> _cancel() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Ride Cancel karein?'),
          content: TextField(
              controller: c,
              decoration: const InputDecoration(hintText: 'Reason (optional)')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Nahi')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, c.text),
                child: const Text('Haan, Cancel')),
          ],
        );
      },
    );
    if (reason == null) return;
    try {
      await Api.I.cancelRide(widget.rideId, reason);
      _refresh();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _sos() async {
    try {
      await Api.I.sos(rideId: widget.rideId);
      _snack('SOS bhej diya gaya. Madad aa rahi hai.');
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _rate() async {
    int stars = 5;
    final comment = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Driver ko rate karein'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => IconButton(
                  icon: Icon(i < stars ? Icons.star : Icons.star_border,
                      color: Colors.amber, size: 32),
                  onPressed: () => setS(() => stars = i + 1),
                ),
              ),
            ),
            TextField(
                controller: comment,
                decoration:
                    const InputDecoration(hintText: 'Comment (optional)')),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Submit')),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await Api.I.rateRide(widget.rideId, stars, comment.text);
        setState(() => _rated = true);
        _snack('Rating ke liye dhanyavaad!');
      } catch (e) {
        _snack(e.toString());
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _statusLabel(String s) {
    switch (s) {
      case 'requested':
        return 'Driver dhundha ja raha hai...';
      case 'accepted':
        return 'Driver aa raha hai';
      case 'arrived':
        return 'Driver pickup par pahunch gaya';
      case 'ongoing':
        return 'Ride chal rahi hai';
      case 'completed':
        return 'Ride complete!';
      case 'cancelled':
        return 'Ride cancel ho gayi';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(AppConfig.brandGreen);
    if (_ride == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final r = _ride!;
    final status = r['status'] as String;
    final driver = r['driver'] as Map<String, dynamic>?;
    final pickup = LatLng(
        double.parse(r['pickup_lat'].toString()),
        double.parse(r['pickup_lng'].toString()));
    final drop = LatLng(double.parse(r['drop_lat'].toString()),
        double.parse(r['drop_lng'].toString()));
    LatLng? driverPos;
    if (driver != null &&
        driver['current_lat'] != null &&
        driver['current_lng'] != null) {
      driverPos = LatLng(double.parse(driver['current_lat'].toString()),
          double.parse(driver['current_lng'].toString()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(r['ride_code'] as String),
        actions: [
          IconButton(
              icon: const Icon(Icons.sos, color: Colors.redAccent),
              onPressed: _sos),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: FlutterMap(
            options: MapOptions(initialCenter: pickup, initialZoom: 14),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'app.humsafar.rider',
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
                    child:
                        const Icon(Icons.trip_origin, color: green, size: 28)),
                Marker(
                    point: drop,
                    width: 36,
                    height: 36,
                    child: const Icon(Icons.location_on,
                        color: Colors.red, size: 32)),
                if (driverPos != null)
                  Marker(
                      point: driverPos,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.two_wheeler,
                          color: Colors.black87, size: 32)),
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
                Row(children: [
                  Icon(
                      status == 'completed'
                          ? Icons.check_circle
                          : status == 'cancelled'
                              ? Icons.cancel
                              : Icons.directions_bike,
                      color: status == 'cancelled' ? Colors.red : green),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(_statusLabel(status),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600))),
                  Text('₹${r['final_fare'] ?? r['estimated_fare']}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: green)),
                ]),
                if (status == 'accepted' || status == 'arrived') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const CircleAvatar(child: Icon(Icons.person)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(driver?['name'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text('⭐ ${driver?['rating'] ?? '5.0'}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.black54)),
                            ]),
                      ),
                      Column(children: [
                        const Text('Ride OTP',
                            style: TextStyle(
                                fontSize: 11, color: Colors.black45)),
                        Text(r['otp']?.toString() ?? '----',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 4,
                                color: green)),
                      ]),
                    ]),
                  ),
                ],
                const SizedBox(height: 12),
                if (['requested', 'accepted', 'arrived'].contains(status))
                  OutlinedButton(
                    onPressed: _cancel,
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        minimumSize: const Size.fromHeight(46)),
                    child: const Text('Ride Cancel Karein'),
                  ),
                if (status == 'completed' && !_rated)
                  ElevatedButton(
                      onPressed: _rate,
                      child: const Text('⭐ Driver ko Rate Karein')),
                if (status == 'completed' || status == 'cancelled')
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Home par jayein')),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
