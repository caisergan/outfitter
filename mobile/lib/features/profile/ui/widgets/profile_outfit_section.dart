import 'package:flutter/material.dart';

import 'package:fashion_app/core/models/outfit_models.dart';
import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';

class ProfileOutfitSection extends StatelessWidget {
  final String title;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;
  final List<SavedOutfit> outfits;
  final Set<String> likedOutfitIds;
  final ValueChanged<SavedOutfit> onTap;
  final ValueChanged<String> onToggleLike;

  const ProfileOutfitSection({
    required this.title,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.outfits,
    required this.likedOutfitIds,
    required this.onTap,
    required this.onToggleLike,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        if (outfits.isEmpty)
          _EmptyOutfitState(
            icon: emptyIcon,
            title: emptyTitle,
            message: emptyMessage,
          )
        else
          SizedBox(
            height: 206,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: outfits.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final outfit = outfits[index];
                return _OutfitPreviewCard(
                  outfit: outfit,
                  isLiked: likedOutfitIds.contains(outfit.id),
                  onTap: () => onTap(outfit),
                  onToggleLike: () => onToggleLike(outfit.id),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _OutfitPreviewCard extends StatelessWidget {
  final SavedOutfit outfit;
  final bool isLiked;
  final VoidCallback onTap;
  final VoidCallback onToggleLike;

  const _OutfitPreviewCard({
    required this.outfit,
    required this.isLiked,
    required this.onTap,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 148,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    outfit.generatedImageUrl != null
                        ? CachedItemImage(url: outfit.generatedImageUrl!)
                        : Container(
                            color: AppColors.backgroundSecondary,
                            child: const Icon(
                              Icons.checkroom_outlined,
                              color: AppColors.text,
                              size: 32,
                            ),
                          ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: AppColors.paper.withValues(alpha: 0.94),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onToggleLike,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border_outlined,
                              color: isLiked
                                  ? AppColors.primary
                                  : AppColors.secondaryText,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outfit ${outfit.id.substring(0, 4)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(outfit.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

class _EmptyOutfitState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyOutfitState({
    required this.icon,
    required this.title,
    required this.message,
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
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.secondaryText,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
