import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../services/api.dart';
import '../services/geo_service.dart';
import 'search_screen.dart';
import 'ride_screen.dart';
import 'history_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';

/// Rapido-style home:
/// 1. GPS se pickup auto-set (asli address ke saath)
/// 2. "Kahan jana hai?" -> search ya map-pin se drop chunein
/// 3. OSRM se asli road route + fare options bottom sheet
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _Stage { idle, pinPickup, pinDrop, options }

class _HomeScreenState extends State<HomeScreen> {
  final _map = MapController();
  static const _fallback = LatLng(27.1591, 78.3958); // Firozabad

  List<dynamic> _cities = [];
  int? _cityId;

  LatLng? _pickup;
  LatLng? _drop;
  String _pickupAddr = 'Aapki location dhundhi ja rahi hai...';
  String _dropAddr = '';

  _Stage _stage = _Stage.idle;
  LatLng _pinCenter = _fallback;
  String _pinAddr = '';
  Timer? _pinDebounce;

  List<LatLng> _routePoints = [];
  List<dynamic> _fareOptions = [];
  int? _selectedVt;
  String _payment = 'cash';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _pinDebounce?.cancel();
    super.dispose();
  }

  Future<void> _boot() async {
    try {
      final data = await Api.I.bootstrap();
      if (!mounted) return;
      setState(() {
        _cities = data['cities'] as List<dynamic>;
        if (_cities.isNotEmpty) _cityId = _cities.first['id'] as int;
      });
    } catch (_) {}
    await _locateMe();
  }

  Future<void> _locateMe() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        setState(() => _pickupAddr = 'Location permission dein');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      _map.move(here, 16);
      setState(() {
        _pickup = here;
        _pickupAddr = 'Address mil raha hai...';
      });
      _autoSelectCity(here);
      final addr = await GeoService.reverseGeocode(here);
      if (mounted) setState(() => _pickupAddr = addr);
    } catch (_) {
      if (mounted) {
        setState(() => _pickupAddr = 'Location nahi mili — pin se chunein');
      }
    }
  }

  /// Sabse paas wali city apne aap select.
  void _autoSelectCity(LatLng p) {
    if (_cities.isEmpty) return;
    const d = Distance();
    dynamic best;
    double bestKm = double.infinity;
    for (final c in _cities) {
      if (c['center_lat'] == null) continue;
      final km = d.as(
          LengthUnit.Kilometer,
          p,
          LatLng(double.parse(c['center_lat'].toString()),
              double.parse(c['center_lng'].toString())));
      if (km < bestKm) {
        bestKm = km;
        best = c;
      }
    }
    if (best != null) setState(() => _cityId = best['id'] as int);
  }

  // ---------- Destination / pickup choose ----------

  Future<void> _openSearch({required bool forPickup}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SearchScreen(
              title: forPickup ? 'Pickup chunein' : 'Kahan jana hai?',
              near: _pickup)),
    );
    if (result == null) return;
    if (result == 'PIN_ON_MAP') {
      _startPinMode(forPickup: forPickup);
    } else if (result is PlaceResult) {
      if (forPickup) {
        setState(() {
          _pickup = result.point;
          _pickupAddr = result.name;
        });
        _map.move(result.point, 16);
        _autoSelectCity(result.point);
      } else {
        setState(() {
          _drop = result.point;
          _dropAddr = result.name;
        });
      }
      _maybeShowOptions();
    }
  }

  void _startPinMode({required bool forPickup}) {
    setState(() {
      _stage = forPickup ? _Stage.pinPickup : _Stage.pinDrop;
      _pinCenter = (forPickup ? _pickup : _drop) ?? _pickup ?? _fallback;
      _pinAddr = 'Map ghumayein...';
      _fareOptions = [];
      _routePoints = [];
    });
    _map.move(_pinCenter, 17);
    _reversePin();
  }

  void _onMapMoved(MapCamera camera, bool hasGesture) {
    if (_stage != _Stage.pinPickup && _stage != _Stage.pinDrop) return;
    _pinCenter = camera.center;
    _pinDebounce?.cancel();
    _pinDebounce = Timer(const Duration(milliseconds: 600), _reversePin);
  }

  Future<void> _reversePin() async {
    if (!mounted) return;
    setState(() => _pinAddr = 'Address mil raha hai...');
    final addr = await GeoService.reverseGeocode(_pinCenter);
    if (mounted) setState(() => _pinAddr = addr);
  }

  void _confirmPin() {
    if (_stage == _Stage.pinPickup) {
      setState(() {
        _pickup = _pinCenter;
        _pickupAddr = _pinAddr;
        _stage = _Stage.idle;
      });
      _autoSelectCity(_pinCenter);
    } else {
      setState(() {
        _drop = _pinCenter;
        _dropAddr = _pinAddr;
        _stage = _Stage.idle;
      });
    }
    _maybeShowOptions();
  }

  // ---------- Route + fares ----------

  Future<void> _maybeShowOptions() async {
    if (_pickup == null || _drop == null || _cityId == null) return;
    setState(() {
      _loading = true;
      _stage = _Stage.options;
      _routePoints = [];
    });

    final routeFuture = GeoService.route(_pickup!, _drop!);
    final fareFuture = Api.I.estimateFare(
      cityId: _cityId!,
      pickupLat: _pickup!.latitude,
      pickupLng: _pickup!.longitude,
      dropLat: _drop!.latitude,
      dropLng: _drop!.longitude,
    );

    try {
      final route = await routeFuture;
      final fares = await fareFuture;
      if (!mounted) return;
      setState(() {
        _routePoints = route?.points ?? [_pickup!, _drop!];
        _fareOptions = fares['options'] as List<dynamic>;
        if (_fareOptions.isNotEmpty) {
          _selectedVt = _fareOptions.first['vehicle_type_id'] as int;
        }
      });
      _fitRoute();
    } catch (e) {
      _snack(e.toString());
      if (mounted) setState(() => _stage = _Stage.idle);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fitRoute() {
    if (_pickup == null || _drop == null) return;
    final pts = _routePoints.isNotEmpty ? _routePoints : [_pickup!, _drop!];
    final bounds = LatLngBounds.fromPoints(pts);
    _map.fitCamera(CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.fromLTRB(40, 120, 40, 340)));
  }

  Future<void> _book() async {
    if (_selectedVt == null) return;
    setState(() => _loading = true);
    try {
      final data = await Api.I.bookRide({
        'city_id': _cityId,
        'vehicle_type_id': _selectedVt,
        'pickup_address': _pickupAddr,
        'pickup_lat': _pickup!.latitude,
        'pickup_lng': _pickup!.longitude,
        'drop_address': _dropAddr,
        'drop_lat': _drop!.latitude,
        'drop_lng': _drop!.longitude,
        'payment_method': _payment,
      });
      if (!mounted) return;
      final ride = data['ride'] as Map<String, dynamic>;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => RideScreen(rideId: ride['id'] as int)));
      _reset();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reset() => setState(() {
        _drop = null;
        _dropAddr = '';
        _routePoints = [];
        _fareOptions = [];
        _selectedVt = null;
        _stage = _Stage.idle;
      });

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _emoji(String slug) =>
      {'bike': '🏍️', 'auto': '🛺', 'e_rickshaw': '🛺'}[slug] ?? '🚗';

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    const green = Color(AppConfig.brandGreen);
    final pinMode = _stage == _Stage.pinPickup || _stage == _Stage.pinDrop;

    return Scaffold(
      body: Stack(children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _pickup ?? _fallback,
            initialZoom: 15,
            onPositionChanged: _onMapMoved,
          ),
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
              if (_pickup != null && !pinMode)
                Marker(
                    point: _pickup!,
                    width: 40,
                    height: 40,
                    child: _dotMarker(green)),
              if (_drop != null && !pinMode)
                Marker(
                    point: _drop!,
                    width: 44,
                    height: 44,
                    child: const Icon(Icons.location_on,
                        color: Colors.red, size: 40)),
            ]),
          ],
        ),

        // Center pin (Rapido style)
        if (pinMode)
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 44),
                child: Icon(Icons.location_on,
                    size: 48,
                    color: _stage == _Stage.pinPickup ? green : Colors.red),
              ),
            ),
          ),

        // Top card
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: pinMode ? _pinTopCard(green) : _topCard(green),
          ),
        ),

        // My location FAB
        Positioned(
          right: 14,
          bottom: _stage == _Stage.options ? 350 : 190,
          child: FloatingActionButton.small(
            heroTag: 'loc',
            backgroundColor: Colors.white,
            foregroundColor: green,
            onPressed: _locateMe,
            child: const Icon(Icons.my_location),
          ),
        ),

        // Bottom sheet
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0, 0.15), end: Offset.zero)
                  .animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: pinMode
                ? _pinConfirmSheet(green)
                : _stage == _Stage.options
                    ? _optionsSheet(green)
                    : _whereToSheet(green),
          ),
        ),
      ]),
    );
  }

  Widget _dotMarker(Color c) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(blurRadius: 6, color: Colors.black26)
            ]),
        padding: const EdgeInsets.all(5),
        child: Container(
            decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      );

  Widget _topCard(Color green) => Card(
        elevation: 4,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          child: Row(children: [
            Icon(Icons.trip_origin, color: green, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => _openSearch(forPickup: true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(_pickupAddr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14)),
                ),
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.menu),
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'history', child: Text('📜  Ride History')),
                PopupMenuItem(value: 'wallet', child: Text('💰  Wallet')),
                PopupMenuItem(value: 'profile', child: Text('👤  Profile')),
              ],
              onSelected: (v) {
                Widget page;
                if (v == 'history') {
                  page = const HistoryScreen();
                } else if (v == 'wallet') {
                  page = const WalletScreen();
                } else {
                  page = const ProfileScreen();
                }
                Navigator.push(
                    context, MaterialPageRoute(builder: (_) => page));
              },
            ),
          ]),
        ),
      );

  Widget _pinTopCard(Color green) => Card(
        elevation: 4,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(Icons.location_on,
                color: _stage == _Stage.pinPickup ? green : Colors.red),
            const SizedBox(width: 10),
            Expanded(
                child: Text(_pinAddr,
                    maxLines: 2, style: const TextStyle(fontSize: 13))),
          ]),
        ),
      );

  Widget _whereToSheet(Color green) => Container(
        key: const ValueKey('whereTo'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: _sheetDeco,
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(
                alignment: Alignment.centerLeft,
                child: Text('Namaste! 👋',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _openSearch(forPickup: false),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(children: [
                  const Icon(Icons.search, color: Colors.black54),
                  const SizedBox(width: 12),
                  Text('Kahan jana hai?',
                      style: TextStyle(
                          fontSize: 16, color: Colors.grey.shade700)),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _startPinMode(forPickup: false),
                icon: const Icon(Icons.pin_drop, size: 18),
                label: const Text('Map par pin lagakar chunein'),
              ),
            ),
          ]),
        ),
      );

  Widget _pinConfirmSheet(Color green) => Container(
        key: const ValueKey('pinConfirm'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: _sheetDeco,
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ElevatedButton(
              onPressed: _confirmPin,
              child: Text(_stage == _Stage.pinPickup
                  ? '✓  Yahi Pickup Hai'
                  : '✓  Yahi Jana Hai'),
            ),
            TextButton(
                onPressed: () => setState(() => _stage = _Stage.idle),
                child: const Text('Cancel')),
          ]),
        ),
      );

  Widget _optionsSheet(Color green) => Container(
        key: const ValueKey('options'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: _sheetDeco,
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              const Icon(Icons.location_on, color: Colors.red, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_dropAddr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontWeight: FontWeight.w600))),
              TextButton(onPressed: _reset, child: const Text('Badlein')),
            ]),
            const Divider(height: 8),
            if (_loading && _fareOptions.isEmpty)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator())
            else ...[
              ...List.generate(_fareOptions.length, (i) {
                final o = _fareOptions[i] as Map<String, dynamic>;
                final sel = o['vehicle_type_id'] == _selectedVt;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: sel ? green.withOpacity(0.08) : Colors.white,
                    border: Border.all(
                        color: sel ? green : Colors.grey.shade300,
                        width: sel ? 2 : 1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ListTile(
                    dense: true,
                    onTap: () => setState(
                        () => _selectedVt = o['vehicle_type_id'] as int),
                    leading: Text(_emoji(o['slug'] as String),
                        style: const TextStyle(fontSize: 26)),
                    title: Text(o['name'] as String,
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${o['distance_km']} km · ~${(o['duration_min'] as num).round()} min',
                        style: const TextStyle(fontSize: 12)),
                    trailing: Text('₹${(o['total_fare'] as num).round()}',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: sel ? green : Colors.black87)),
                  ),
                );
              }),
              const SizedBox(height: 6),
              Row(children: [
                const Text('Payment:', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 10),
                ChoiceChip(
                    label: const Text('💵 Cash'),
                    selected: _payment == 'cash',
                    onSelected: (_) => setState(() => _payment = 'cash')),
                const SizedBox(width: 8),
                ChoiceChip(
                    label: const Text('📱 UPI'),
                    selected: _payment == 'upi',
                    onSelected: (_) => setState(() => _payment = 'upi')),
              ]),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _loading ? null : _book,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Book Karein',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
        ),
      );

  BoxDecoration get _sheetDeco => const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(blurRadius: 14, color: Colors.black26)],
      );
}
