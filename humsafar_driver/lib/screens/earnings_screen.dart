import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  Map<String, dynamic>? _earnings;
  List<dynamic> _txns = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final e = await Api.I.earnings();
      final w = await Api.I.wallet();
      setState(() {
        _earnings = e;
        _txns = w['transactions'] as List<dynamic>;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(AppConfig.brandGreen);
    return Scaffold(
      appBar: AppBar(title: const Text('Meri Kamai')),
      body: _earnings == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  _card('Aaj', '₹${_earnings!['today']?['earning'] ?? 0}',
                      '${_earnings!['today']?['rides'] ?? 0} rides', green),
                  const SizedBox(width: 12),
                  _card(
                      'Is Hafte',
                      '₹${_earnings!['week']?['earning'] ?? 0}',
                      '${_earnings!['week']?['rides'] ?? 0} rides',
                      Colors.teal),
                ]),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [green, Color(0xFF158a3b)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Wallet Balance',
                            style: TextStyle(color: Colors.white70)),
                        Text('₹${_earnings!['wallet_balance'] ?? 0}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        const Text('Settlement admin dwara hoti hai',
                            style: TextStyle(
                                color: Colors.white60, fontSize: 11)),
                      ]),
                ),
                const SizedBox(height: 16),
                const Text('Recent Transactions',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (_txns.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text('Koi transaction nahi.'))),
                ..._txns.map((t) {
                  final m = t as Map<String, dynamic>;
                  final credit = m['type'] == 'credit';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                        credit ? Icons.arrow_downward : Icons.arrow_upward,
                        color: credit ? green : Colors.red),
                    title: Text(m['reason']?.toString() ?? ''),
                    trailing: Text('${credit ? '+' : '-'}₹${m['amount']}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: credit ? green : Colors.red)),
                  );
                }),
              ]),
            ),
    );
  }

  Widget _card(String label, String value, String sub, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            Text(value,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            Text(sub,
                style: const TextStyle(fontSize: 11, color: Colors.black45)),
          ]),
        ),
      );
}
