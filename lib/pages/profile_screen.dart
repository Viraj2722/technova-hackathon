import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/app_header.dart';
import '../services/user_service.dart'; // <-- Import UserService


class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Not logged in, redirect to login
      Future.microtask(() => Navigator.of(context).pushReplacementNamed('/login'));
      return const Center(child: CircularProgressIndicator());
    }
    final displayName = user.displayName ?? (user.email != null ? user.email!.split('@')[0] : 'User');
    final email = user.email ?? '';
    final initial = (displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppHeader(),
          const SizedBox(height: 24),
          const Text(
            'Profile & Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          // Profile Info
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue[100],
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Menu Items
          _buildMenuItem(Icons.person, 'Account Information', Colors.grey[700]!, onTap: null),
          const SizedBox(height: 8),
          _buildMenuItem(Icons.settings, 'App Settings', Colors.grey[700]!, onTap: null),
          const SizedBox(height: 8),
          _buildMenuItem(Icons.help_outline, 'Help & Support', Colors.grey[700]!, onTap: null),
          const SizedBox(height: 8),
          _buildMenuItem(Icons.logout, 'Log Out', Colors.red[600]!, onTap: () async {
            await FirebaseAuth.instance.signOut();
            await UserService.clearUserData(); // <-- Add this line!
            if (context.mounted) {
              Navigator.of(context).pushReplacementNamed('/login');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logged out successfully.'), backgroundColor: Colors.red),
              );
            }
          }),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
