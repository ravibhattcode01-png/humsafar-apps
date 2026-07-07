import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../services/geo_service.dart';

/// Rapido-style destination search — type karo, suggestions milengi.
class SearchScreen extends StatefulWidget {
  final String title;
  final LatLng? near;
  const SearchScreen({super.key, required this.title, this.near});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  List<PlaceResult> _results = [];
  bool _searching = false;

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      if (q.trim().length < 3) {
        setState(() => _results = []);
        return;
      }
      setState(() => _searching = true);
      final r = await GeoService.search(q, near: widget.near);
      if (!mounted) return;
      setState(() {
        _results = r;
        _searching = false;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(AppConfig.brandGreen);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            decoration: InputDecoration(
              hintText: 'Jagah ka naam likhein... (min 3 letters)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : (_controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _results = []);
                          })
                      : null),
            ),
          ),
        ),
        // "Map par pin lagayein" option
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: green.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.pin_drop, color: green),
          ),
          title: const Text('Map par pin lagakar chunein'),
          subtitle: const Text('Map ghumakar exact jagah select karein',
              style: TextStyle(fontSize: 12)),
          onTap: () => Navigator.pop(context, 'PIN_ON_MAP'),
        ),
        const Divider(height: 1),
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text(
                      _controller.text.trim().length < 3
                          ? 'Jagah dhundhein — jaise "Railway Station Firozabad"'
                          : (_searching ? '' : 'Kuch nahi mila, aur likhein...'),
                      style: const TextStyle(color: Colors.black38)))
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final p = _results[i];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined,
                          color: Colors.black45),
                      title: Text(p.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(p.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
