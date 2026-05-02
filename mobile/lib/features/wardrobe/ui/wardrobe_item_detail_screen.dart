import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/wardrobe_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_helpers.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../providers/wardrobe_provider.dart';
import '/features/tryon/providers/styling_canvas_provider.dart';

class WardrobeItemDetailScreen extends ConsumerWidget {
  final String itemId;

  const WardrobeItemDetailScreen({required this.itemId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wardrobeState = ref.watch(wardrobeNotifierProvider);

    return wardrobeState.when(
      data: (items) {
        WardrobeItem? item;
        for (final entry in items) {
          if (entry.id == itemId) {
            item = entry;
            break;
          }
        }

        if (item == null) {
          return const Scaffold(
            backgroundColor: AppColors.cream,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final resolvedItem = item;

        return Scaffold(
          backgroundColor: AppColors.cream,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: IconButton(
                      tooltip: 'Delete item',
                      onPressed: () => _confirmDelete(context, ref),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (resolvedItem.category ?? resolvedItem.slot).toUpperCase(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: AppColors.textMuted,
                                    letterSpacing: 1.1,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _titleCase(
                                resolvedItem.subcategory ??
                                    resolvedItem.category ??
                                    resolvedItem.slot,
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .displaySmall
                                  ?.copyWith(
                                    fontSize: 34,
                                  ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              height: 320,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceAlt,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.all(18),
                              child: CachedItemImage(
                                url: resolvedItem.imageUrl,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Details',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 18),
                            _MetaField(
                              label: 'Slot',
                              value: _titleCase(resolvedItem.slot),
                            ),
                            if (resolvedItem.category != null)
                              _MetaField(
                                label: 'Category',
                                value: _titleCase(resolvedItem.category!),
                              ),
                            if (resolvedItem.subcategory != null)
                              _MetaField(
                                label: 'Subcategory',
                                value: _titleCase(resolvedItem.subcategory!),
                              ),
                            if (resolvedItem.pattern?.isNotEmpty ?? false)
                              _MetaField(
                                label: 'Pattern',
                                value: resolvedItem.pattern!
                                    .map(_titleCase)
                                    .join(', '),
                              ),
                            if (resolvedItem.fit?.isNotEmpty ?? false)
                              _MetaField(
                                label: 'Fit',
                                value: _titleCase(resolvedItem.fit!),
                              ),
                            if (resolvedItem.styleTags.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Text(
                                'Style tags',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: resolvedItem.styleTags
                                    .map(
                                      (tag) => _NeutralPill(
                                        label: _titleCase(tag),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            if (resolvedItem.color.isNotEmpty) ...[
                              const SizedBox(height: 18),
                              Text(
                                'Palette',
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: resolvedItem.color
                                    .map((color) => _ColorSwatch(label: color))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () =>
                            _addToTryOn(context, ref, resolvedItem),
                        child: const Text('Add to Studio'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => context.go(
                          '/assistant',
                          extra: {'anchorItemId': resolvedItem.id},
                        ),
                        child: const Text('Style This Piece'),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Similar in your wardrobe',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 14),
                      _buildSimilarItems(context, items, resolvedItem),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, __) => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(),
        body: ErrorView(
          message: dioErrorToMessage(e),
          onRetry: () => ref.read(wardrobeNotifierProvider.notifier).fetch(),
        ),
      ),
    );
  }

  Widget _buildSimilarItems(
    BuildContext context,
    List<WardrobeItem> items,
    WardrobeItem current,
  ) {
    final similar = items
        .where((item) => item.id != current.id && item.slot == current.slot)
        .take(4)
        .toList();

    if (similar.isEmpty) {
      return Text(
        'No similar items found yet.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
      );
    }

    return SizedBox(
      height: 158,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: similar.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = similar[index];
          return SizedBox(
            width: 122,
            child: Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: () => context.push('/wardrobe/item/${item.id}'),
                borderRadius: BorderRadius.circular(24),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: CachedItemImage(
                      url: item.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _addToTryOn(
    BuildContext context,
    WidgetRef ref,
    WardrobeItem item,
  ) {
    ref.read(stylingCanvasProvider.notifier).addWardrobeGarment(item);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to Studio')),
    );
    context.go('/tryon');
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this item?'),
        content: Text(
          'This will permanently remove the piece from your wardrobe.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(wardrobeNotifierProvider.notifier).deleteItem(itemId);
      if (context.mounted) context.pop();
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, dioErrorToMessage(e));
    }
  }

  static String _titleCase(String value) {
    return value
        .split(' ')
        .map((word) =>
            word.isEmpty ? word : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}

class _MetaField extends StatelessWidget {
  final String label;
  final String value;

  const _MetaField({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 0.9,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeutralPill extends StatelessWidget {
  final String label;

  const _NeutralPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.text,
            ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final String label;

  const _ColorSwatch({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: _nameToColor(label),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            WardrobeItemDetailScreen._titleCase(label),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }

  Color _nameToColor(String name) {
    const colors = {
      'red': Color(0xFF9E5E54),
      'blue': Color(0xFF75869A),
      'green': Color(0xFF71806B),
      'yellow': Color(0xFFD6B56B),
      'orange': Color(0xFFC88758),
      'purple': Color(0xFF8A7A92),
      'pink': Color(0xFFD0A4A4),
      'black': Color(0xFF2F2A27),
      'white': Color(0xFFF4EFE7),
      'grey': Color(0xFF9B948E),
      'gray': Color(0xFF9B948E),
      'brown': Color(0xFF8A6A52),
      'beige': Color(0xFFD9C7B0),
      'navy': Color(0xFF364252),
      'cream': Color(0xFFF0E4D2),
      'mint': Color(0xFFAFB9A8),
      'lavender': Color(0xFFB4A7BA),
      'olive': Color(0xFF7A7B58),
    };
    return colors[name.toLowerCase()] ?? AppColors.mint;
  }
}
