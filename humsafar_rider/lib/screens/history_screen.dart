import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api.dart';
import 'ride_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic>? _rides;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.I.history();
      final page = data['rides'] as Map<String, dynamic>;
      setState(() => _rides = page['data'] as List<dynamic>);
    } catch (_) {
      setState(() => _rides = []);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed':
        return const Color(AppConfig.brandGreen);
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride History')),
      body: _rides == null
          ? const Center(child: CircularProgressIndicator())
          : _rides!.isEmpty
              ? const Center(child: Text('Abhi tak koi ride nahi.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _rides!.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final r = _rides![i] as Map<String, dynamic>;
                      final st = r['status'] as String;
                      return Card(
                        child: ListTile(
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      RideScreen(rideId: r['id'] as int))),
                          leading: CircleAvatar(
                            backgroundColor:
                                _statusColor(st).withOpacity(0.15),
                            child: Icon(Icons.directions_bike,
                                color: _statusColor(st), size: 20),
                          ),
                          title: Text(r['ride_code'] as String,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${r['pickup_address']} → ${r['drop_address']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('₹${r['final_fare'] ?? r['estimated_fare']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              Text(st,
                                  style: TextStyle(
                                      fontSize: 11, color: _statusColor(st))),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
