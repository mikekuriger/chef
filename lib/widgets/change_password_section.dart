// widgets/change_password_section.dart
import 'package:flutter/material.dart';
import 'package:chef/services/api_service.dart';

class ChangePasswordSection extends StatefulWidget {
  const ChangePasswordSection({super.key});

  @override
  State<ChangePasswordSection> createState() => _ChangePasswordSectionState();
}

class _ChangePasswordSectionState extends State<ChangePasswordSection> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtl = TextEditingController();
  final _newCtl = TextEditingController();
  final _confirmCtl = TextEditingController();

  bool _ob1 = true, _ob2 = true, _ob3 = true;
  bool _saving = false;
  String? _error;
  String? _ok;
  bool _expanded = false;

  String? _req(String? v) => (v == null || v.isEmpty) ? 'Required' : null;

  Future<void> _submit() async {
    if (_saving) return;
    setState(() { _error = null; _ok = null; });

    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_newCtl.text != _confirmCtl.text) {
      setState(() => _error = 'New passwords do not match');
      return;
    }
    if (_newCtl.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters');
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiService.changePassword(
        currentPassword: _currentCtl.text,
        newPassword: _newCtl.text,
      );
      setState(() => _ok = 'Password changed successfully');
      _currentCtl.clear(); _newCtl.clear(); _confirmCtl.clear();
    } catch (e) {
      setState(() => _error = 'Current password incorrect or policy not met');
    } finally {
      setState(() => _saving = false);
    }
  }

  Widget _pwField({
    required TextEditingController ctl,
    required bool obscure,
    required VoidCallback toggle,
    required String label,
  }) {
    return TextFormField(
      controller: ctl,
      obscureText: obscure,
      validator: _req,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
        suffixIcon: IconButton(
          onPressed: toggle,
          icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row collapsible
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.white),
                  const SizedBox(width: 8),
                  const Text('Change Password', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more, color: Colors.white),
                ],
              ),
            ),
            if (_expanded) const SizedBox(height: 12),

            if (_expanded && _error != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ),

            if (_expanded && _ok != null)
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.18),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Password changed successfully', style: TextStyle(color: Colors.green)),
              ),

            if (_expanded)
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    _pwField(
                      ctl: _currentCtl,
                      obscure: _ob1,
                      toggle: () => setState(() => _ob1 = !_ob1),
                      label: 'Current password',
                    ),
                    const SizedBox(height: 12),
                    _pwField(
                      ctl: _newCtl,
                      obscure: _ob2,
                      toggle: () => setState(() => _ob2 = !_ob2),
                      label: 'New password',
                    ),
                    const SizedBox(height: 12),
                    _pwField(
                      ctl: _confirmCtl,
                      obscure: _ob3,
                      toggle: () => setState(() => _ob3 = !_ob3),
                      label: 'Confirm new password',
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(140, 42),
                        ),
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Update Password'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
