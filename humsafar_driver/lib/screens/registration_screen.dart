import 'package:flutter/material.dart';
import '../services/api.dart';

/// Driver KYC registration.
/// Note: file-picker deliberately simple rakha hai (image_picker plugin add
/// karke files bhi bhej sakte hain — Api.I.register 'files' support karta hai).
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _aadhar = TextEditingController();
  final _pan = TextEditingController();
  final _dl = TextEditingController();
  final _rc = TextEditingController();
  final _upi = TextEditingController();

  List<dynamic> _cities = [];
  List<dynamic> _vehicleTypes = [];
  int? _cityId;
  int? _vehicleTypeId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      final data = await Api.I.bootstrap();
      setState(() {
        _cities = data['cities'] as List<dynamic>;
        _vehicleTypes = data['vehicle_types'] as List<dynamic>;
      });
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_cityId == null || _vehicleTypeId == null) {
      _snack('City aur vehicle type chunein');
      return;
    }
    setState(() => _loading = true);
    try {
      await Api.I.register({
        'name': _name.text.trim(),
        'city_id': _cityId.toString(),
        'vehicle_type_id': _vehicleTypeId.toString(),
        'aadhar_number': _aadhar.text.trim(),
        'pan_number': _pan.text.trim(),
        'dl_number': _dl.text.trim(),
        'registration_number': _rc.text.trim(),
        'upi_id': _upi.text.trim(),
      });
      if (!mounted) return;
      _snack('Registration jama ho gaya! Admin approval ka intezaar karein.');
      Navigator.pop(context);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Driver Registration')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Poora Naam *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Naam zaroori hai' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _cityId,
              decoration: const InputDecoration(labelText: 'City *'),
              items: _cities
                  .map((c) => DropdownMenuItem<int>(
                      value: c['id'] as int, child: Text(c['name'] as String)))
                  .toList(),
              onChanged: (v) => setState(() => _cityId = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _vehicleTypeId,
              decoration: const InputDecoration(labelText: 'Vehicle Type *'),
              items: _vehicleTypes
                  .map((v) => DropdownMenuItem<int>(
                      value: v['id'] as int, child: Text(v['name'] as String)))
                  .toList(),
              onChanged: (v) => setState(() => _vehicleTypeId = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aadhar,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Aadhar Number *'),
              validator: (v) => (v == null || v.trim().length < 12)
                  ? '12-digit Aadhar daalein'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dl,
              decoration:
                  const InputDecoration(labelText: 'Driving License Number *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'DL zaroori hai' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _rc,
              decoration: const InputDecoration(
                  labelText: 'Gaadi RC / Registration Number *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'RC zaroori hai' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pan,
              decoration:
                  const InputDecoration(labelText: 'PAN Number (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _upi,
              decoration: const InputDecoration(
                  labelText: 'UPI ID (payout ke liye, optional)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 22, width: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Karein'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Documents (Aadhar/DL/RC photo) admin ko alag se bhi bheje ja sakte hain. Approval hone par aap online ja sakenge.',
              style: TextStyle(fontSize: 12, color: Colors.black45),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
