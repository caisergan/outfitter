import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/core/utils/error_helpers.dart';
import 'package:fashion_app/features/assistant/data/outfit_repository.dart';
import 'package:fashion_app/features/playground/providers/slot_builder_provider.dart';

class TryOnResultView extends ConsumerWidget {
  final String imageUrl;
  final VoidCallback onEdit;

  const TryOnResultView({required this.imageUrl, required this.onEdit, super.key});

  Future<void> _handleSave(BuildContext context, WidgetRef ref) async {
    final slots = ref.read(slotBuilderProvider);
    try {
      await ref.read(outfitRepositoryProvider).save(
        source: 'playground',
        slots: slots.slotIds,
        generatedImageUrl: imageUrl,
      );
      if (context.mounted) showSuccessSnackbar(context, 'Outfit saved to Lookbook!');
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, dioErrorToMessage(e));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedItemImage(url: imageUrl, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _ResultAction(icon: Icons.bookmark_outline, label: 'Save', onTap: () => _handleSave(context, ref))),
              const SizedBox(width: 12),
              Expanded(child: _ResultAction(icon: Icons.share_outlined, label: 'Share', onTap: () => Share.share('Check out my outfit! $imageUrl'))),
              const SizedBox(width: 12),
              Expanded(child: _ResultAction(icon: Icons.edit_outlined, label: 'Edit', onTap: onEdit)),
            ],
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: Colors.grey.shade300)),
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

  const _ResultAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, size: 20, color: Colors.grey.shade700),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}
