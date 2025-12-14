// screens/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:chef/services/api_service.dart';
import 'package:chef/theme/colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  bool _sending = false;
  String? _msg;

  String? _validateEmail(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(s)) return 'Invalid email';
    return null;
  }

  Future<void> _send() async {
    if (_sending) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _sending = true;
      _msg = null;
    });

    try {
      await ApiService.requestPasswordReset(_emailCtl.text.trim());
      setState(() => _msg = 'If that email exists, a reset link was sent.');
    } catch (e) {
      // Intentionally vague to avoid user enumeration
      setState(() => _msg = 'If that email exists, a reset link was sent.');
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password'), backgroundColor: AppColors.purple950),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Enter your account email. We’ll send a password reset link.',
              style: TextStyle(color: Colors.white)),
          const SizedBox(height: 16),
          if (_msg != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.18),
                border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_msg!, style: const TextStyle(color: Colors.green)),
            ),
          Form(
            key: _formKey,
            child: TextFormField(
              controller: _emailCtl,
              validator: _validateEmail,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Email",
                labelStyle: TextStyle(color: Colors.white),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
            child: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }
}
