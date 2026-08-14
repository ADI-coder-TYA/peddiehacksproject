import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class HealthProfileScreen extends StatelessWidget {
  const HealthProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Health Profile'),
        backgroundColor: const Color(0xFF0D9488),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: const Color(0xFF0D9488).withOpacity(0.15),
                  child: const Icon(Icons.person_outline,
                      size: 48, color: Color(0xFF0D9488)),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D9488),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _profileField('Full Name', 'Alex Rivera', Icons.person_outline),
          _profileField('Student / Employee ID', 'STU-2024-001', Icons.badge_outlined),
          _profileField('Institution', 'Campus Health Network', Icons.school_outlined),
          _profileField('Insurance Plan', 'BlueCross Campus Gold', Icons.health_and_safety_outlined),
          _profileField('Emergency Contact', '+1 (555) 012-3456', Icons.phone_outlined),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.lock_outline, color: Color(0xFF0D9488)),
            title: const Text('Privacy & HIPAA Consent'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined, color: Color(0xFF0D9488)),
            title: const Text('Clinical Alert Preferences'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
            title: const Text('Sign Out',
                style: TextStyle(color: Color(0xFFEF4444))),
            onTap: () => auth.signOut(),
          ),
        ],
      ),
    );
  }

  Widget _profileField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF0D9488)),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
