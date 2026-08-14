import 'package:flutter/material.dart';

class BiometricAuthScreen extends StatefulWidget {
  const BiometricAuthScreen({super.key});

  @override
  State<BiometricAuthScreen> createState() => _BiometricAuthScreenState();
}

class _BiometricAuthScreenState extends State<BiometricAuthScreen> {
  bool _isAuthenticating = false;

  Future<void> _authenticateWithBiometrics() async {
    setState(() => _isAuthenticating = true);
    // Placeholder: integrate local_auth in production
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _isAuthenticating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric auth successful')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fingerprint, size: 72, color: Color(0xFF0D9488)),
            const SizedBox(height: 24),
            const Text(
              'MedAccess AI',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F766E),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap to authenticate with biometrics',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            _isAuthenticating
                ? const CircularProgressIndicator(color: Color(0xFF0D9488))
                : ElevatedButton.icon(
                    onPressed: _authenticateWithBiometrics,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Authenticate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
