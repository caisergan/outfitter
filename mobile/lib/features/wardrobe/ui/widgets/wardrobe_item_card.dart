import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:fashion_app/core/models/wardrobe_item.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import '/core/theme/app_colors.dart';

class WardrobeItemCard extends StatelessWidget {
  final WardrobeItem item;

  const WardrobeItemCard({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle =
        '${item.color.isNotEmpty ? item.color.first : ''} ${item.subtype ?? item.category}'
            .trim();

    return GestureDetector(
      onTap: () => context.go('/wardrobe/item/${item.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.backgroundElevated,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: AppColors.surface,
                padding: const EdgeInsets.all(18),
                child: CachedItemImage(
                  url: item.imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (item.subtype ?? item.category).toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle.isEmpty ? 'Wardrobe item' : subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
