import 'package:flutter/material.dart';

import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/features/profile/data/profile_repository.dart';

class ProfileSettingsSection extends StatelessWidget {
  final ProfileSettings settings;
  final ValueChanged<ProfileSettings> onChanged;

  const ProfileSettingsSection({
    required this.settings,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
            child: Text(
              'Notification & Privacy',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _SettingsSwitchTile(
            title: 'Outfit reminders',
            subtitle: 'Nudges for looks you saved but have not worn.',
            icon: Icons.notifications_active_outlined,
            value: settings.outfitReminders,
            onChanged: (value) =>
                onChanged(settings.copyWith(outfitReminders: value)),
          ),
          _SettingsSwitchTile(
            title: 'Style drop alerts',
            subtitle: 'New seasonal edits and catalog matches.',
            icon: Icons.auto_awesome_outlined,
            value: settings.styleDropAlerts,
            onChanged: (value) =>
                onChanged(settings.copyWith(styleDropAlerts: value)),
          ),
          _SettingsSwitchTile(
            title: 'Private profile',
            subtitle: 'Keep your lookbook visible only to you.',
            icon: Icons.lock_outline,
            value: settings.privateProfile,
            onChanged: (value) =>
                onChanged(settings.copyWith(privateProfile: value)),
          ),
          _SettingsSwitchTile(
            title: 'Personalized picks',
            subtitle: 'Use wardrobe activity to improve recommendations.',
            icon: Icons.verified_user_outlined,
            value: settings.personalizedRecommendations,
            onChanged: (value) => onChanged(
              settings.copyWith(personalizedRecommendations: value),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      secondary: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon, color: AppColors.primary, size: 18),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.secondaryText,
            ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
    );
  }
}
