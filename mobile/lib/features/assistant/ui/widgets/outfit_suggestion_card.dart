import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fashion_app/core/models/outfit_models.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/core/utils/error_helpers.dart';
import 'package:fashion_app/features/assistant/data/outfit_repository.dart';

class OutfitSuggestionCard extends ConsumerWidget {
  final OutfitSuggestion outfit;

  const OutfitSuggestionCard({required this.outfit, super.key});

  Future<void> _handleSave(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(outfitRepositoryProvider).save(
            source: 'assistant',
            slots: outfit.slots.map((k, v) => MapEntry(k, v.toJson())),
          );
      if (context.mounted) {
        showSuccessSnackbar(context, 'Outfit saved to Lookbook!');
      }
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, dioErrorToMessage(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildStackedImages()),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  outfit.styleNote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.go('/playground', extra: {
                          'slots':
                              outfit.slots
                                  .map((k, v) => MapEntry(k, v.imageUrl)),
                        }),
                        child: const Text('Try On'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.bookmark_border),
                      onPressed: () => _handleSave(context, ref),
                      style: IconButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStackedImages() {
    final slotItems = outfit.slots.values.toList();
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: CachedItemImage(
            url: slotItems[0].imageUrl,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(24)),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(
                child: CachedItemImage(
                  url: slotItems[1].imageUrl,
                  borderRadius:
                      const BorderRadius.only(topRight: Radius.circular(24)),
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: CachedItemImage(
                  url: slotItems.length > 2
                      ? slotItems[2].imageUrl
                      : slotItems[0].imageUrl,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
