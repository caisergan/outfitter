import 'package:flutter/material.dart';

import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/features/profile/data/profile_repository.dart';

class ProfileHeader extends StatelessWidget {
  final ProfileUser user;
  final VoidCallback onEdit;
  final VoidCallback onSettings;

  const ProfileHeader({
    required this.user,
    required this.onEdit,
    required this.onSettings,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileAvatar(user: user),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.secondaryText,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Settings',
                onPressed: onSettings,
                icon: const Icon(
                  Icons.settings_outlined,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            user.bio.trim().isEmpty
                ? 'Add a short bio to personalize your styling profile.'
                : user.bio,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  color: user.bio.trim().isEmpty
                      ? AppColors.secondaryText
                      : AppColors.text,
                ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit Profile'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSettings,
                  icon: const Icon(
                    Icons.privacy_tip_outlined,
                    size: 18,
                  ),
                  label: const Text('Privacy'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final ProfileUser user;

  const _ProfileAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final photoUrl = user.photoUrl;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.divider),
        ),
        child: ClipOval(
          child: CachedItemImage(
            url: photoUrl,
            width: 82,
            height: 82,
          ),
        ),
      );
    }

    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.paper,
        border: Border.all(color: AppColors.divider),
      ),
      alignment: Alignment.center,
      child: Text(
        user.initials,
        style: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w800,
          fontSize: 24,
        ),
      ),
    );
  }
}
