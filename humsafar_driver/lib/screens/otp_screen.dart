import 'package:flutter/material.dart';
import '../services/api.dart';
import 'home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _otp = TextEditingController();
  final _name = TextEditingController();
  bool _loading = false;

  Future<void> _verify() async {
    if (_otp.text.trim().length < 4) return;
    setState(() => _loading = true);
    try {
      await Api.I.verifyOtp(widget.phone, _otp.text.trim(),
          name: _name.text.trim());
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('OTP Verify')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('+91 ${widget.phone} par OTP bheja gaya hai',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 24),
            TextField(
              controller: _otp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 12),
              decoration:
                  const InputDecoration(labelText: 'OTP', counterText: ''),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Aapka Naam (naye drivers ke liye)',
                  prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _verify,
              child: _loading
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Verify & Login'),
            ),
          ],
        ),
      ),
    );
  }
}
