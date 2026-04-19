import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '/core/theme/app_colors.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.cream,

      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.text),
          onPressed: () {
            context.go('/discover');
          },
        ),
        title: const Text(
          'Profile',
          style: TextStyle(color: AppColors.text),
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            // 👤 Center profile section
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.lightMint,
                    child: Icon(Icons.person, size: 50, color: AppColors.text),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your Profile',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your account settings and preferences',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.text.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // 🚪 Logout button (UI only)
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.blush,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    // TODO: logout later
                  },
                  child: const Text('Logout'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}