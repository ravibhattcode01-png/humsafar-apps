import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config.dart';
import '../services/api.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});
  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  Map<String, dynamic>? _data;
  final _applyCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.I.referral();
      if (mounted) setState(() => _data = d);
    } catch (_) {}
  }

  Future<void> _apply() async {
    if (_applyCtrl.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final r = await Api.I.applyReferral(_applyCtrl.text.trim());
      _snack(r['message']?.toString() ?? 'Ho gaya!');
      _load();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    const green = Color(AppConfig.brandGreen);
    return Scaffold(
      appBar: AppBar(title: const Text('Refer & Earn')),
      body: _data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [green, Color(0xFF158a3b)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  const Text('Aapka Referral Code',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(_data!['code']?.toString() ?? '',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70)),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: _data!['code'].toString()));
                      _snack('Code copy ho gaya!');
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy Karein'),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.group, color: green),
                  title: Text('${_data!['referred_count'] ?? 0} logo ne join kiya'),
                  subtitle: Text(
                      'Unki pehli ride par aapko ₹${(_data!['bonus_referrer'] as num?)?.round() ?? 50}, unhe ₹${(_data!['bonus_referee'] as num?)?.round() ?? 25} milta hai'),
                ),
              ),
              const SizedBox(height: 16),
              if (_data!['applied_code'] == null) ...[
                const Text('Kisi ka code hai? Yahan lagayein:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _applyCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration:
                          const InputDecoration(hintText: 'e.g. HSAB12CD'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(90, 50)),
                    onPressed: _busy ? null : _apply,
                    child: const Text('Apply'),
                  ),
                ]),
              ] else
                Card(
                  child: ListTile(
                    leading:
                        const Icon(Icons.check_circle, color: green),
                    title: Text('Code lagaya: ${_data!['applied_code']}'),
                    subtitle: const Text(
                        'Pehli ride complete hote hi bonus wallet me aayega'),
                  ),
                ),
            ]),
    );
  }
}
