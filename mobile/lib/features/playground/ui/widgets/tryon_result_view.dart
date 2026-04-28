import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/core/utils/error_helpers.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/features/assistant/data/outfit_repository.dart';
import 'package:fashion_app/features/playground/providers/slot_builder_provider.dart';

class TryOnResultView extends ConsumerWidget {
  final String imageUrl;
  final VoidCallback onEdit;

  const TryOnResultView({
    required this.imageUrl,
    required this.onEdit,
    super.key,
  });

  Future<void> _handleSave(BuildContext context, WidgetRef ref) async {
    final slots = ref.read(slotBuilderProvider);
    try {
      await ref.read(outfitRepositoryProvider).save(
            source: 'playground',
            slots: slots.slotIds,
            generatedImageUrl: imageUrl,
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedItemImage(url: imageUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Rendered look',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Save the result to your lookbook, share it, or reopen the studio to keep refining the silhouette.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _ResultAction(
                  icon: Icons.bookmark_outline,
                  label: 'Save',
                  onTap: () => _handleSave(context, ref),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ResultAction(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () => Share.share('Check out my outfit! $imageUrl'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ResultAction(
                  icon: Icons.edit_outlined,
                  label: 'Edit',
                  onTap: onEdit,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onEdit,
            child: const Text('Build Another Outfit'),
          ),
        ],
      ),
    );
  }
}

class _ResultAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ResultAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: AppColors.blush),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
