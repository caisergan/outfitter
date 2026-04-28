import 'package:flutter/material.dart';

import 'package:fashion_app/core/models/outfit_models.dart';
import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';

class ItemDetailSheet extends StatelessWidget {
  final SlotItem item;

  const ItemDetailSheet({required this.item, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.surfaceAlt,
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedItemImage(url: item.imageUrl),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.brand,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.textMuted,
                              letterSpacing: 0.8,
                            )),
                    const SizedBox(height: 4),
                    Text(item.name,
                        style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {},
            child: const Text('View Official Page'),
          ),
          const SizedBox(height: 12),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
