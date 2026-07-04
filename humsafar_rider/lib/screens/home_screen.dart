import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../services/api.dart';
import 'ride_screen.dart';
import 'history_screen.dart';
import 'wallet_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _mapController = MapController();
  final _pickupAddr = TextEditingController();
  final _dropAddr = TextEditingController();

  List<dynamic> _cities = [];
  int? _cityId;

  LatLng? _pickup;
  LatLng? _drop;
  bool _selectingDrop = true; // map tap sets drop by default

  List<dynamic> _fareOptions = [];
  int? _selectedVehicleTypeId;
  String _paymentMethod = 'cash';
  bool _loading = false;

  static const _fallbackCenter = LatLng(27.1591, 78.3958); // Firozabad

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final data = await Api.I.bootstrap();
      setState(() {
        _cities = data['cities'] as List<dynamic>;
        if (_cities.isNotEmpty) _cityId = _cities.first['id'] as int;
      });
    } catch (_) {}
    await _locate();
  }

  Future<void> _locate() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _pickup = here;
        _pickupAddr.text =
            'Current location (${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)})';
      });
      _mapController.move(here, 15);
    } catch (_) {}
  }

  void _onMapTap(TapPosition _, LatLng point) {
    setState(() {
      if (_selectingDrop) {
        _drop = point;
        _dropAddr.text =
            'Pin (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
      } else {
        _pickup = point;
        _pickupAddr.text =
            'Pin (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
      }
      _fareOptions = [];
      _selectedVehicleTypeId = null;
    });
  }

  Future<void> _getFares() async {
    if (_cityId == null || _pickup == null || _drop == null) {
      _snack('Pickup aur Drop dono select karein (map par tap karke)');
      return;
    }
    setState(() => _loading = true);
    try {
      final data = await Api.I.estimateFare(
        cityId: _cityId!,
        pickupLat: _pickup!.latitude,
        pickupLng: _pickup!.longitude,
        dropLat: _drop!.latitude,
        dropLng: _drop!.longitude,
      );
      setState(() {
        _fareOptions = data['options'] as List<dynamic>;
        if (_fareOptions.isNotEmpty) {
          _selectedVehicleTypeId = _fareOptions.first['vehicle_type_id'] as int;
        }
      });
    } catch (e) {
      _snack(e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _book() async {
    if (_selectedVehicleTypeId == null) return;
    setState(() => _loading = true);
    try {
      final data = await Api.I.bookRide({
        'city_id': _cityId,
        'vehicle_type_id': _selectedVehicleTypeId,
        'pickup_address': _pickupAddr.text,
        'pickup_lat': _pickup!.latitude,
        'pickup_lng': _pickup!.longitude,
        'drop_address': _dropAddr.text,
        'drop_lat': _drop!.latitude,
        'drop_lng': _drop!.longitude,
        'payment_method': _paymentMethod,
      });
      if (!mounted) return;
      final ride = data['ride'] as Map<String, dynamic>;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RideScreen(rideId: ride['id'] as int)),
      ).then((_) => setState(() {
            _fareOptions = [];
            _selectedVehicleTypeId = null;
            _drop = null;
            _dropAddr.clear();
          }));
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _vehicleEmoji(String slug) {
    switch (slug) {
      case 'bike':
        return '🏍️';
      case 'auto':
        return '🛺';
      case 'e_rickshaw':
        return '🛺';
      default:
        return '🚗';
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(AppConfig.brandGreen);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Humsafar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const WalletScreen())),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- Map ----
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _pickup ?? _fallbackCenter,
                    initialZoom: 14,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'app.humsafar.rider',
                    ),
                    MarkerLayer(markers: [
                      if (_pickup != null)
                        Marker(
                          point: _pickup!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.my_location,
                              color: green, size: 32),
                        ),
                      if (_drop != null)
                        Marker(
                          point: _drop!,
                          width: 40,
                          height: 40,
                          child: const Icon(Icons.location_on,
                              color: Colors.red, size: 36),
                        ),
                    ]),
                  ],
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(children: [
                        Row(children: [
                          const Icon(Icons.trip_origin,
                              color: green, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _pickupAddr,
                              onTap: () =>
                                  setState(() => _selectingDrop = false),
                              decoration: InputDecoration(
                                hintText: 'Pickup — map par tap karein',
                                border: InputBorder.none,
                                isDense: true,
                                filled: !_selectingDrop,
                                fillColor: green.withOpacity(0.08),
                              ),
                            ),
                          ),
                          IconButton(
                              icon: const Icon(Icons.gps_fixed, size: 18),
                              onPressed: _locate),
                        ]),
                        const Divider(height: 1),
                        Row(children: [
                          const Icon(Icons.location_on,
                              color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _dropAddr,
                              onTap: () =>
                                  setState(() => _selectingDrop = true),
                              decoration: InputDecoration(
                                hintText: 'Drop — map par tap karein',
                                border: InputBorder.none,
                                isDense: true,
                                filled: _selectingDrop,
                                fillColor: Colors.red.withOpacity(0.06),
                              ),
                            ),
                          ),
                        ]),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ---- Bottom sheet: city, fares, book ----
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(blurRadius: 8, color: Colors.black12)],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_cities.isNotEmpty)
                    DropdownButtonFormField<int>(
                      value: _cityId,
                      decoration: const InputDecoration(
                          labelText: 'City', isDense: true),
                      items: _cities
                          .map((c) => DropdownMenuItem<int>(
                              value: c['id'] as int,
                              child: Text(c['name'] as String)))
                          .toList(),
                      onChanged: (v) => setState(() => _cityId = v),
                    ),
                  const SizedBox(height: 10),
                  if (_fareOptions.isEmpty)
                    ElevatedButton(
                      onPressed: _loading ? null : _getFares,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Fare Dekhein'),
                    )
                  else ...[
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _fareOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final o = _fareOptions[i] as Map<String, dynamic>;
                          final sel = o['vehicle_type_id'] ==
                              _selectedVehicleTypeId;
                          return GestureDetector(
                            onTap: () => setState(() =>
                                _selectedVehicleTypeId =
                                    o['vehicle_type_id'] as int),
                            child: Container(
                              width: 120,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: sel
                                    ? green.withOpacity(0.1)
                                    : Colors.grey.shade100,
                                border: Border.all(
                                    color: sel ? green : Colors.grey.shade300,
                                    width: sel ? 2 : 1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_vehicleEmoji(o['slug'] as String),
                                      style: const TextStyle(fontSize: 20)),
                                  Text(o['name'] as String,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  Text('₹${o['total_fare']}',
                                      style: const TextStyle(
                                          color: green,
                                          fontWeight: FontWeight.bold)),
                                  Text('${o['distance_km']} km',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.black45)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Text('Payment: '),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Cash'),
                        selected: _paymentMethod == 'cash',
                        onSelected: (_) =>
                            setState(() => _paymentMethod = 'cash'),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('UPI'),
                        selected: _paymentMethod == 'upi',
                        onSelected: (_) =>
                            setState(() => _paymentMethod = 'upi'),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loading ? null : _book,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Book Karein'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
