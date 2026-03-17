import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fashion_app/core/models/slot_type.dart';
import 'package:fashion_app/core/models/catalog_item.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/features/playground/providers/slot_builder_provider.dart';
import 'item_browser_sheet.dart';

class PlaygroundStackPanel extends ConsumerWidget {
  const PlaygroundStackPanel({super.key});

  void _openSlotBrowser(BuildContext context, WidgetRef ref, SlotType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ItemBrowserSheet(
        type: type,
        onItemSelected: (item) {},
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(slotBuilderProvider).slots;

    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'STACK',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                ...SlotType.values.take(4).map((type) {
                  final item = slots[type];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _StackSlotTile(
                      type: type,
                      item: item,
                      onTap: () => _openSlotBrowser(context, ref, type),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StackSlotTile extends StatelessWidget {
  final SlotType type;
  final CatalogItem? item;
  final VoidCallback onTap;

  const _StackSlotTile({
    required this.type,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: item == null ? Colors.white.withOpacity(0.3) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: item != null 
                ? Border.all(color: const Color(0xFF1D5CE0), width: 3)
                : Border.all(color: Colors.white.withOpacity(0.4), width: 1),
              boxShadow: [
                if (item != null)
                  BoxShadow(
                    color: const Color(0xFF1D5CE0).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: item == null 
                ? Center(
                    child: Icon(
                      _getIconForType(type),
                      color: Colors.black45,
                      size: 24,
                    ),
                  )
                : CachedItemImage(url: item!.imageUrl),
            ),
          ),
          if (item != null)
            Positioned(
              top: -8,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D5CE0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _getShortLabel(type),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getShortLabel(SlotType type) {
    return switch (type) {
      SlotType.top => 'TOP',
      SlotType.bottom => 'BTM',
      SlotType.shoes => 'SHOE',
      SlotType.accessory => 'ACC',
      SlotType.outerwear => 'OUT',
      SlotType.bag => 'BAG',
    };
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
        return Icons.watch_outlined;
      case SlotType.outerwear:
        return Icons.dry_cleaning;
      case SlotType.bag:
        return Icons.shopping_bag_outlined;
    }
  }
}
