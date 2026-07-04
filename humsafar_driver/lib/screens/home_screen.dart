import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../config.dart';
import '../services/api.dart';
import 'registration_screen.dart';
import 'ride_screen.dart';
import 'earnings_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _profile;
  bool _online = false;
  List<dynamic> _rides = [];
  Map<String, dynamic>? _earnings;
  Timer? _pollTimer;
  Timer? _gpsTimer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _gpsTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await Api.I.profile();
      final e = await Api.I.earnings();
      if (!mounted) return;
      setState(() {
        _profile = p['profile'] as Map<String, dynamic>;
        _online = _profile!['is_online'] == true || _profile!['is_online'] == 1;
        _earnings = e;
      });
      if (_online) _startPolling();
    } catch (_) {}
  }

  Future<Position?> _position() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _snack('Location permission zaroori hai online jaane ke liye');
        return null;
      }
      return await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleOnline(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (value) {
        final pos = await _position();
        if (pos == null) return;
        await Api.I.setOnline(true, lat: pos.latitude, lng: pos.longitude);
        _startPolling();
      } else {
        await Api.I.setOnline(false);
        _stopPolling();
      }
      setState(() => _online = value);
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _gpsTimer?.cancel();
    _fetchRides();
    // Nayi rides har 6 second check (production: FCM push)
    _pollTimer =
        Timer.periodic(const Duration(seconds: 6), (_) => _fetchRides());
    // GPS ping har 15 second
    _gpsTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      final pos = await _position();
      if (pos != null) {
        try {
          await Api.I.pingLocation(pos.latitude, pos.longitude);
        } catch (_) {}
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _gpsTimer?.cancel();
    setState(() => _rides = []);
  }

  Future<void> _fetchRides() async {
    try {
      final data = await Api.I.availableRides();
      if (!mounted) return;
      setState(() => _rides = data['rides'] as List<dynamic>);
    } catch (_) {}
  }

  Future<void> _accept(Map<String, dynamic> ride) async {
    try {
      final data = await Api.I.acceptRide(ride['id'] as int);
      if (!mounted) return;
      _stopPolling();
      await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) =>
                RideScreen(ride: data['ride'] as Map<String, dynamic>)),
      );
      _load();
      if (_online) _startPolling();
    } catch (e) {
      _snack(e.toString());
      _fetchRides();
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    const green = Color(AppConfig.brandGreen);
    if (_profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final status = _profile!['status'] as String? ?? 'pending';

    // ---- Approval gate ----
    if (status != 'approved') {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Humsafar Partner'),
          actions: [
            IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await Api.I.logout();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (_) => false);
                }),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    status == 'pending'
                        ? Icons.hourglass_top
                        : Icons.error_outline,
                    size: 64,
                    color: status == 'pending' ? Colors.orange : Colors.red),
                const SizedBox(height: 16),
                Text(
                  status == 'pending'
                      ? 'Aapka account verification me hai'
                      : status == 'rejected'
                          ? 'Application reject hui: ${_profile!['rejection_reason'] ?? ''}'
                          : 'Account suspended hai. Support se baat karein.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                if (status == 'pending' &&
                    (_profile!['aadhar_number'] == null))
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const RegistrationScreen())).then((_) => _load()),
                    child: const Text('Registration Complete Karein'),
                  ),
                if (status == 'rejected')
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const RegistrationScreen())).then((_) => _load()),
                    child: const Text('Documents Dobara Bharein'),
                  ),
                TextButton(onPressed: _load, child: const Text('Refresh')),
              ],
            ),
          ),
        ),
      );
    }

    // ---- Approved driver home ----
    return Scaffold(
      appBar: AppBar(
        title: const Text('Humsafar Partner'),
        actions: [
          IconButton(
              icon: const Icon(Icons.currency_rupee),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const EarningsScreen()))),
          IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await Api.I.logout();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false);
              }),
        ],
      ),
      body: Column(children: [
        // Online toggle bar
        Container(
          color: _online ? green : Colors.grey.shade800,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            Icon(_online ? Icons.wifi : Icons.wifi_off,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(_online ? 'Aap ONLINE hain' : 'Aap OFFLINE hain',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600))),
            Switch(
              value: _online,
              activeColor: Colors.white,
              onChanged: _busy ? null : _toggleOnline,
            ),
          ]),
        ),

        // Earnings strip
        if (_earnings != null)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: Row(children: [
              _stat('Aaj', '₹${_earnings!['today']?['earning'] ?? 0}',
                  '${_earnings!['today']?['rides'] ?? 0} rides'),
              _stat('Is Hafte', '₹${_earnings!['week']?['earning'] ?? 0}',
                  '${_earnings!['week']?['rides'] ?? 0} rides'),
              _stat('Wallet', '₹${_earnings!['wallet_balance'] ?? 0}', ''),
            ]),
          ),

        // Available rides
        Expanded(
          child: !_online
              ? const Center(
                  child: Text('Online jayein rides dekhne ke liye',
                      style: TextStyle(color: Colors.black45)))
              : _rides.isEmpty
                  ? const Center(
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Nayi rides ka intezaar...',
                              style: TextStyle(color: Colors.black45)),
                        ]))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _rides.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final r = _rides[i] as Map<String, dynamic>;
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.trip_origin,
                                      color: green, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Text(
                                          r['pickup_address'] as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis)),
                                ]),
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.location_on,
                                      color: Colors.red, size: 16),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Text(r['drop_address'] as String,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis)),
                                ]),
                                const SizedBox(height: 8),
                                Row(children: [
                                  Text('₹${r['estimated_fare']}',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: green)),
                                  const SizedBox(width: 12),
                                  Text('${r['estimated_distance_km']} km',
                                      style: const TextStyle(
                                          color: Colors.black54)),
                                  if (r['pickup_distance_km'] != null) ...[
                                    const SizedBox(width: 12),
                                    Text(
                                        'Pickup ${r['pickup_distance_km']} km door',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black45)),
                                  ],
                                  const Spacer(),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(100, 40)),
                                    onPressed: () => _accept(r),
                                    child: const Text('Accept'),
                                  ),
                                ]),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value, String sub) => Expanded(
        child: Column(children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.black45)),
          Text(value,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          if (sub.isNotEmpty)
            Text(sub,
                style:
                    const TextStyle(fontSize: 10, color: Colors.black38)),
        ]),
      );
}
