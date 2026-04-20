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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.lightMint.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.mint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Style Preferences',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.text,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.tune, size: 18, color: AppColors.blush),
                label: const Text(
                  'Edit',
                  style: TextStyle(color: AppColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (preferences.isEmpty)
            Text(
              'Set favorite occasions, seasons, and palettes for better outfit suggestions.',
              style: TextStyle(
                color: AppColors.text.withValues(alpha: 0.68),
                height: 1.3,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.mint),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.blush),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
