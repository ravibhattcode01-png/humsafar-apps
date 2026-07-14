import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../services/api.dart';
import '../services/geo_service.dart';
import 'package:url_launcher/url_launcher.dart';

class RideScreen extends StatefulWidget {
  final int rideId;
  const RideScreen({super.key, required this.rideId});
  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  final _map = MapController();
  Map<String, dynamic>? _ride;
  List<LatLng> _routePoints = [];
  Timer? _timer;
  bool _rated = false;
  bool _fitted = false;

  static const _steps = ['requested', 'accepted', 'arrived', 'ongoing', 'completed'];

  @override
  void initState() {
    super.initState();
    _refresh();
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
      final ride = data['ride'] as Map<String, dynamic>;
      final firstLoad = _ride == null;
      setState(() => _ride = ride);

      if (firstLoad) _loadRoute();
      final st = ride['status'] as String;
      if (st == 'completed' || st == 'cancelled') _timer?.cancel();
    } catch (_) {}
  }

  Future<void> _loadRoute() async {
    final r = _ride!;
    final pickup = _latLng(r['pickup_lat'], r['pickup_lng']);
    final drop = _latLng(r['drop_lat'], r['drop_lng']);
    final route = await GeoService.route(pickup, drop);
    if (!mounted) return;
    setState(() => _routePoints = route?.points ?? [pickup, drop]);
    if (!_fitted) {
      _fitted = true;
      _map.fitCamera(CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(_routePoints),
          padding: const EdgeInsets.fromLTRB(40, 100, 40, 320)));
    }
  }

  LatLng _latLng(dynamic lat, dynamic lng) =>
      LatLng(double.parse(lat.toString()), double.parse(lng.toString()));

  Future<void> _cancel() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Ride cancel karein?'),
          content: TextField(
              controller: c,
              decoration:
                  const InputDecoration(hintText: 'Reason (optional)')),
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
      _snack('🆘 SOS bhej diya gaya. Madad aa rahi hai.');
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
          title: const Text('Ride kaisi rahi?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => IconButton(
                  icon: Icon(i < stars ? Icons.star : Icons.star_border,
                      color: Colors.amber, size: 34),
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
        _snack('Rating ke liye dhanyavaad! 🙏');
      } catch (e) {
        _snack(e.toString());
      }
    }
  }

  Future<void> _callDriver(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openInvoice() async {
    try {
      final r = await Api.I.invoiceUrl(widget.rideId);
      final uri = Uri.parse(r['url'] as String);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      _snack(e.toString());
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _statusLabel(String s) => switch (s) {
        'requested' => 'Driver dhundha ja raha hai...',
        'accepted' => 'Driver aa raha hai 🏍️',
        'arrived' => 'Driver pahunch gaya — OTP batayein',
        'ongoing' => 'Ride chal rahi hai',
        'completed' => 'Ride complete! 🎉',
        'cancelled' => 'Ride cancel ho gayi',
        _ => s,
      };

  @override
  Widget build(BuildContext context) {
    const green = Color(AppConfig.brandGreen);
    if (_ride == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final r = _ride!;
    final status = r['status'] as String;
    final driver = r['driver'] as Map<String, dynamic>?;
    final pickup = _latLng(r['pickup_lat'], r['pickup_lng']);
    final drop = _latLng(r['drop_lat'], r['drop_lng']);
    LatLng? driverPos;
    if (driver != null &&
        driver['current_lat'] != null &&
        driver['current_lng'] != null) {
      driverPos = _latLng(driver['current_lat'], driver['current_lng']);
    }
    final stepIndex = _steps.indexOf(status);

    return Scaffold(
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(initialCenter: pickup, initialZoom: 14),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'app.humsafar.rider',
            ),
            if (_routePoints.isNotEmpty)
              PolylineLayer(polylines: [
                Polyline(points: _routePoints, strokeWidth: 6, color: green),
                Polyline(
                    points: _routePoints,
                    strokeWidth: 2.5,
                    color: Colors.white.withOpacity(0.7)),
              ]),
            MarkerLayer(markers: [
              Marker(
                  point: pickup,
                  width: 36,
                  height: 36,
                  child:
                      const Icon(Icons.trip_origin, color: green, size: 26)),
              Marker(
                  point: drop,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on,
                      color: Colors.red, size: 36)),
              if (driverPos != null)
                Marker(
                  point: driverPos,
                  width: 46,
                  height: 46,
                  child: Container(
                    decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(blurRadius: 6, color: Colors.black26)
                        ]),
                    child: const Icon(Icons.two_wheeler,
                        color: Colors.black87, size: 28),
                  ),
                ),
            ]),
          ],
        ),

        // Top bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              _circleBtn(Icons.arrow_back,
                  onTap: () => Navigator.pop(context)),
              const Spacer(),
              if (!['completed', 'cancelled'].contains(status))
                _circleBtn(Icons.sos, color: Colors.red, onTap: _sos),
            ]),
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
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(blurRadius: 14, color: Colors.black26)],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status + fare
                  Row(children: [
                    Expanded(
                        child: Text(_statusLabel(status),
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold))),
                    Text('₹${((r['final_fare'] ?? r['estimated_fare']) as num).round()}',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: green)),
                  ]),
                  const SizedBox(height: 10),

                  // Progress stepper
                  if (status != 'cancelled')
                    Row(
                      children: List.generate(4, (i) {
                        final done = stepIndex > i ||
                            (status == 'completed' && i == 3);
                        final active = stepIndex == i;
                        return Expanded(
                          child: Container(
                            height: 5,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: done || active
                                  ? green
                                  : Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        );
                      }),
                    ),
                  const SizedBox(height: 12),

                  // Driver card + OTP
                  if (['accepted', 'arrived', 'ongoing'].contains(status) &&
                      driver != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: green.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        const CircleAvatar(
                            radius: 24, child: Icon(Icons.person, size: 26)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(driver['name']?.toString() ?? '',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                Text(
                                    '⭐ ${driver['rating'] ?? '5.0'}   📞 ${driver['phone'] ?? ''}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54)),
                              ]),
                        ),
                        IconButton(
                          onPressed: () =>
                              _callDriver(driver['phone']?.toString()),
                          icon: const Icon(Icons.call, color: green),
                          style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: green)),
                        ),
                        const SizedBox(width: 6),
                        if (status != 'ongoing')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: green)),
                            child: Column(children: [
                              const Text('OTP',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.black45)),
                              Text(r['otp']?.toString() ?? '----',
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 5,
                                      color: green)),
                            ]),
                          ),
                      ]),
                    ),

                  const SizedBox(height: 12),
                  if (['requested', 'accepted', 'arrived'].contains(status))
                    OutlinedButton(
                      onPressed: _cancel,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          minimumSize: const Size.fromHeight(48)),
                      child: const Text('Ride Cancel Karein'),
                    ),
                  if (status == 'completed' && !_rated)
                    ElevatedButton(
                        onPressed: _rate,
                        child: const Text('⭐ Driver ko Rate Karein')),
                  if (status == 'completed')
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: OutlinedButton.icon(
                        onPressed: _openInvoice,
                        icon: const Icon(Icons.receipt_long, size: 18),
                        label: const Text('Invoice Dekhein / Download'),
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46)),
                      ),
                    ),
                  if (status == 'completed' || status == 'cancelled')
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Home par jayein')),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _circleBtn(IconData icon,
          {Color color = Colors.black87, required VoidCallback onTap}) =>
      Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: color, size: 22)),
        ),
      );
}
