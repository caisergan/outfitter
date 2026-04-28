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
    final label =
        '${item.color.isNotEmpty ? item.color.first[0].toUpperCase() + item.color.first.substring(1) : ''} ${item.subtype ?? item.category}'
            .trim();

    return GestureDetector(
      onTap: () => context.go('/wardrobe/item/${item.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                color: AppColors.backgroundSecondary,
                padding: const EdgeInsets.all(14),
                child: CachedItemImage(
                  url: item.imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.category.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.secondaryText,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          height: 1.3,
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
