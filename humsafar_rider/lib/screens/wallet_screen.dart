import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  double _balance = 0;
  List<dynamic> _txns = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.I.wallet();
      setState(() {
        _balance = double.parse(data['balance'].toString());
        _txns = data['transactions'] as List<dynamic>;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(AppConfig.brandGreen);
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [green, Color(0xFF158a3b)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Balance',
                          style: TextStyle(color: Colors.white70)),
                      Text('₹${_balance.toStringAsFixed(2)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold)),
                    ]),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Transactions',
                        style: TextStyle(fontWeight: FontWeight.w600))),
              ),
              Expanded(
                child: _txns.isEmpty
                    ? const Center(child: Text('Koi transaction nahi.'))
                    : ListView.builder(
                        itemCount: _txns.length,
                        itemBuilder: (_, i) {
                          final t = _txns[i] as Map<String, dynamic>;
                          final credit = t['type'] == 'credit';
                          return ListTile(
                            leading: Icon(
                                credit
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: credit ? green : Colors.red),
                            title: Text(t['reason']?.toString() ?? ''),
                            trailing: Text(
                                '${credit ? '+' : '-'}₹${t['amount']}',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: credit ? green : Colors.red)),
                          );
                        },
                      ),
              ),
            ]),
    );
  }
}
