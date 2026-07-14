import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../config.dart';
import '../services/api.dart';
import '../services/geo_service.dart';
import 'search_screen.dart';

/// Saved addresses (Home / Work / custom).
/// Pop hote waqt selected place (PlaceResult) return karta hai —
/// home screen use drop ke roop me use karti hai.
class FavouritesScreen extends StatefulWidget {
  final LatLng? near;
  const FavouritesScreen({super.key, this.near});
  @override
  State<FavouritesScreen> createState() => _FavouritesScreenState();
}

class _FavouritesScreenState extends State<FavouritesScreen> {
  List<dynamic>? _places;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.I.favourites();
      if (mounted) setState(() => _places = d['places'] as List<dynamic>);
    } catch (_) {
      if (mounted) setState(() => _places = []);
    }
  }

  Future<void> _add() async {
    // 1. Jagah dhundo
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) =>
              SearchScreen(title: 'Jagah dhundhein', near: widget.near)),
    );
    if (result is! PlaceResult) return;

    // 2. Label pucho
    final labelCtrl = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Naam dein'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 8, children: [
            for (final l in ['Home', 'Work', 'Ghar', 'Dukaan'])
              ActionChip(
                  label: Text(l),
                  onPressed: () => Navigator.pop(ctx, l)),
          ]),
          const SizedBox(height: 8),
          TextField(
              controller: labelCtrl,
              decoration: const InputDecoration(hintText: 'Ya custom naam')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, labelCtrl.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (label == null || label.isEmpty) return;

    try {
      await Api.I.addFavourite(
          label, result.address, result.point.latitude, result.point.longitude);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  IconData _icon(String label) {
    final l = label.toLowerCase();
    if (l.contains('home') || l.contains('ghar')) return Icons.home;
    if (l.contains('work') || l.contains('office')) return Icons.work;
    return Icons.star;
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(AppConfig.brandGreen);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Addresses')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: green,
        foregroundColor: Colors.white,
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add karein'),
      ),
      body: _places == null
          ? const Center(child: CircularProgressIndicator())
          : _places!.isEmpty
              ? const Center(
                  child: Text('Koi saved address nahi.\nHome/Work add karein!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black45)))
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _places!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final p = _places![i] as Map<String, dynamic>;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: green.withOpacity(0.1),
                            child: Icon(_icon(p['label'] as String),
                                color: green, size: 20)),
                        title: Text(p['label'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(p['address'] as String,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              size: 20, color: Colors.black38),
                          onPressed: () async {
                            await Api.I.deleteFavourite(p['id'] as int);
                            _load();
                          },
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          PlaceResult(
                            name: p['label'] as String,
                            address: p['address'] as String,
                            point: LatLng(
                                double.parse(p['lat'].toString()),
                                double.parse(p['lng'].toString())),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
