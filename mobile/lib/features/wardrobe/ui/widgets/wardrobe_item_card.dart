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
    final colorLabel =
        item.color.isEmpty ? null : _titleCase(item.color.first).trim();
    final title = _titleCase(item.subcategory ?? item.category ?? item.slot);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => context.go('/wardrobe/item/${item.id}'),
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: CachedItemImage(
                      url: item.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (colorLabel != null) ...[
                      Text(
                        colorLabel.toUpperCase(),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.textMuted,
                                  letterSpacing: 1.0,
                                ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontSize: 21,
                            height: 1.05,
                          ),
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

  String _titleCase(String value) {
    return value
        .split(' ')
        .map((word) =>
            word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
