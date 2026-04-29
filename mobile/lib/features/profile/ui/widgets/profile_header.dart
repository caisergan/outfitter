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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
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
                            color: AppColors.text.withValues(alpha: 0.66),
                          ),
                    ),
                  ],
                ),
              ),
              IconButton.outlined(
                tooltip: 'Settings',
                onPressed: onSettings,
                style: IconButton.styleFrom(
                  side: const BorderSide(color: AppColors.line),
                  foregroundColor: AppColors.text,
                ),
                icon: const Icon(Icons.settings_outlined),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            user.bio.trim().isEmpty
                ? 'Add a short bio to personalize your styling profile.'
                : user.bio,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.35,
                  color: user.bio.trim().isEmpty
                      ? AppColors.text.withValues(alpha: 0.55)
                      : AppColors.text,
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: onSettings,
                icon: const Icon(
                  Icons.privacy_tip_outlined,
                  size: 18,
                ),
                label: const Text('Privacy'),
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
      return ClipOval(
        child: CachedItemImage(
          url: photoUrl,
          width: 76,
          height: 76,
        ),
      );
    }

    return Container(
      width: 76,
      height: 76,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.lightMint,
      ),
      alignment: Alignment.center,
      child: Text(
        user.initials,
        style: const TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w800,
          fontSize: 24,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
