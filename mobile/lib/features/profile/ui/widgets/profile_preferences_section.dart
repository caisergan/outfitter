import 'package:flutter/material.dart';

import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/features/profile/data/profile_repository.dart';

class ProfilePreferencesSection extends StatelessWidget {
  final StylePreferences preferences;
  final VoidCallback onEdit;

  const ProfilePreferencesSection({
    required this.preferences,
    required this.onEdit,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Style Preferences',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Edit'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (preferences.isEmpty)
            Text(
              'Set favorite occasions, seasons, and palettes for better outfit suggestions.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryText,
                  ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PreferencePill(
                  label: _sourceLabel(preferences.sourcePreference),
                  icon: Icons.checkroom_outlined,
                ),
                ...preferences.occasions.map(
                  (value) => _PreferencePill(
                    label: value,
                    icon: Icons.event_available_outlined,
                  ),
                ),
                ...preferences.seasons.map(
                  (value) => _PreferencePill(
                    label: value,
                    icon: Icons.wb_sunny_outlined,
                  ),
                ),
                ...preferences.colorPalettes.map(
                  (value) => _PreferencePill(
                    label: value,
                    icon: Icons.palette_outlined,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'wardrobe':
        return 'My Wardrobe';
      case 'catalog':
        return 'Shop Catalog';
      default:
        return 'Mix Both';
    }
  }
}

class _PreferencePill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _PreferencePill({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                ),
          ),
        ],
      ),
    );
  }
}
