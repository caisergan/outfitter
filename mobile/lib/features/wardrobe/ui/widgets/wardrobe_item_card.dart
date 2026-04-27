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
    return GestureDetector(
      onTap: () => context.go('/wardrobe/item/${item.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lightMint.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: AppColors.mint.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // ── Image — white container, BoxFit.contain so full item shows ──
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.all(10),
                child: CachedItemImage(
                  url: item.imageUrl,
                  fit: BoxFit.contain, // same as detail screen
                ),
              ),
            ),

            // ── Label pill ───────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              color: AppColors.lightMint,
              child: Text(
                '${item.color.isNotEmpty ? item.color.first[0].toUpperCase() + item.color.first.substring(1) : ''} ${item.subtype ?? item.category}'.trim(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}