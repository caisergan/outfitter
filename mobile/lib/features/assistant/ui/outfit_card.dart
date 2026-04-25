import 'package:flutter/material.dart';
import '../../../core/models/outfit_models.dart';
import '/features/assistant/ui/swipe_outfits_screen.dart';

class OutfitCard extends StatelessWidget {
  final OutfitSuggestion outfit;

  const OutfitCard({required this.outfit, super.key});

  @override
  Widget build(BuildContext context) {
    final slots = outfit.slots;

    final top = slots['top'];
    final bottom = slots['bottom'];
    final shoes = slots['shoes'];

    final accessories = slots.entries
        .where((e) =>
    e.key != 'top' &&
        e.key != 'bottom' &&
        e.key != 'shoes')
        .map((e) => e.value)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // MAIN (top, bottom, shoes)
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(child: _itemBox(top)),
                Expanded(child: _itemBox(bottom)),
                Expanded(child: _itemBox(shoes)),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ACCESSORIES SIDE
          Expanded(
            flex: 1,
            child: Column(
              children: accessories
                  .map((a) => Expanded(child: _itemBox(a)))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemBox(SlotItem? item) {
    if (item == null) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.grey[200],
      ),
      child: Image.network(item.imageUrl, fit: BoxFit.cover),
    );
  }
}