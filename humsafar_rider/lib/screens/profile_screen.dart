import 'package:flutter/material.dart';
import '../services/api.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.I.profile();
      setState(() => _profile = data['profile'] as Map<String, dynamic>);
    } catch (_) {}
  }

  Future<void> _logout() async {
    await Api.I.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
              const SizedBox(height: 12),
              Center(
                  child: Text(_profile!['name']?.toString() ?? 'Humsafar User',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
              Center(
                  child: Text('+91 ${_profile!['phone']}',
                      style: const TextStyle(color: Colors.black54))),
              const SizedBox(height: 24),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title:
                    const Text('Logout', style: TextStyle(color: Colors.red)),
                onTap: _logout,
              ),
            ]),
    );
  }
}
