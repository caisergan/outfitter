import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/slot_type.dart';
import 'package:fashion_app/core/models/catalog_item.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/features/tryon/providers/slot_builder_provider.dart';
import 'item_browser_sheet.dart';

class OutfitCanvas extends ConsumerWidget {
  const OutfitCanvas({super.key});

  void _openSlotBrowser(BuildContext context, WidgetRef ref, SlotType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ItemBrowserSheet(
        type: type,
        onItemSelected: (item) {},
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(slotBuilderProvider).slots;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 0.85,
      children: SlotType.values.map((type) {
        final item = slots[type];
        return SlotTile(
          type: type,
          item: item,
          onTap: () => _openSlotBrowser(context, ref, type),
        );
      }).toList(),
    );
  }
}

class SlotTile extends StatelessWidget {
  final SlotType type;
  final CatalogItem? item;
  final VoidCallback onTap;

  const SlotTile({
    required this.type,
    required this.item,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: item == null
                ? Colors.grey.shade200
                : Theme.of(context).primaryColor,
            width: item == null ? 1 : 2,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (item != null)
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: item == null
              ? _buildEmptyState(context)
              : _buildFilledState(context),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(_getIconForType(type), color: Colors.grey.shade400, size: 32),
        const SizedBox(height: 8),
        Text(
          type.displayName,
          style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 12,
              fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildFilledState(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedItemImage(url: item!.imageUrl),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black54],
              ),
            ),
            child: Text(
              item!.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getIconForType(SlotType type) {
    switch (type) {
      case SlotType.top:
        return Icons.checkroom;
      case SlotType.bottom:
        return Icons.inventory_2_outlined;
      case SlotType.shoes:
        return Icons.directions_run_outlined;
      case SlotType.accessory:
        return Icons.watch;
      case SlotType.outerwear:
        return Icons.dry_cleaning;
      case SlotType.bag:
        return Icons.shopping_bag_outlined;
    }
  }
}
