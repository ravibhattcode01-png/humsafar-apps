import 'package:flutter/material.dart';
import '../config.dart';
import '../services/api.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  bool _loading = false;

  Future<void> _sendOtp() async {
    final phone = _phone.text.trim();
    if (!RegExp(r'^[6-9][0-9]{9}$').hasMatch(phone)) {
      _snack('Sahi 10-digit mobile number daalein');
      return;
    }
    setState(() => _loading = true);
    try {
      await Api.I.sendOtp(phone);
      if (!mounted) return;
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => OtpScreen(phone: phone)));
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    const green = Color(AppConfig.brandGreen);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.location_on, size: 72, color: green),
              const SizedBox(height: 12),
              const Text('Humsafar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 32, fontWeight: FontWeight.bold, color: green)),
              const Text('Apne Shehar Ki Sawari',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54)),
              const SizedBox(height: 40),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  prefixText: '+91 ',
                  counterText: '',
                  prefixIcon: Icon(Icons.phone_android),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _sendOtp,
                child: _loading
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('OTP Bhejein'),
              ),
              const Spacer(flex: 2),
              const Text('Bike • Auto • E-Rickshaw — Ek Hi App',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black38, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
