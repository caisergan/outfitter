import 'package:flutter/material.dart';

import '../../../core/models/outfit_models.dart';
import '../../../core/widgets/shared_widgets.dart';

class OutfitLookbookGrid extends StatelessWidget {
  final List<SavedOutfit> outfits;
  final Function(SavedOutfit) onTap;

  const OutfitLookbookGrid({
    required this.outfits,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (outfits.isEmpty) {
      return const Center(
        child: Text('Your lookbook is currently empty.'),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: outfits.length,
      itemBuilder: (context, index) {
        final outfit = outfits[index];
        return GestureDetector(
          onTap: () => onTap(outfit),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: outfit.generatedImageUrl != null
                      ? CachedItemImage(url: outfit.generatedImageUrl!)
                      : Container(
                          color: Colors.grey.shade100,
                          child: const Icon(Icons.checkroom, color: Colors.grey),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Outfit ${outfit.id.substring(0, 4)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
