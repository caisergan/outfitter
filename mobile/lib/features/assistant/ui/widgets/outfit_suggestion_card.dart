import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fashion_app/core/models/outfit_models.dart';
import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/core/utils/error_helpers.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/features/assistant/data/outfit_repository.dart';

class OutfitSuggestionCard extends ConsumerWidget {
  final OutfitSuggestion outfit;

  const OutfitSuggestionCard({required this.outfit, super.key});

  Future<void> _handleSave(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(outfitRepositoryProvider).save(
            source: 'assistant',
            slots: outfit.slots.map((k, v) => MapEntry(k, v.id)),
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildStackedImages()),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STYLED LOOK',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.secondaryText,
                        letterSpacing: 1.4,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  outfit.styleNote,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.go('/playground', extra: {
                          'slots':
                              outfit.slots.map((k, v) => MapEntry(k, v.id)),
                        }),
                        child: const Text('Try On'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton.outlined(
                      icon: const Icon(Icons.bookmark_border),
                      onPressed: () => _handleSave(context, ref),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.paper,
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
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
          child: DecoratedBox(
            decoration: const BoxDecoration(color: AppColors.backgroundSecondary),
            child: CachedItemImage(
              url: slotItems[0].imageUrl,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(24)),
            ),
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration:
                      const BoxDecoration(color: AppColors.backgroundSecondary),
                  child: CachedItemImage(
                    url: slotItems[1].imageUrl,
                    borderRadius:
                        const BorderRadius.only(topRight: Radius.circular(24)),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: DecoratedBox(
                  decoration:
                      const BoxDecoration(color: AppColors.backgroundSecondary),
                  child: CachedItemImage(
                    url: slotItems.length > 2
                        ? slotItems[2].imageUrl
                        : slotItems[0].imageUrl,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
