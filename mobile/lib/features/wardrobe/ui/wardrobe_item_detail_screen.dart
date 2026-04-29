import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_helpers.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shared_widgets.dart';
import '/core/models/wardrobe_item.dart';
import '/core/theme/app_colors.dart';
import '/features/playground/providers/styling_canvas_provider.dart';
import '../providers/wardrobe_provider.dart';

class WardrobeItemDetailScreen extends ConsumerWidget {
  final String itemId;

  const WardrobeItemDetailScreen({required this.itemId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wardrobeState = ref.watch(wardrobeNotifierProvider);

    return wardrobeState.when(
      data: (items) {
        WardrobeItem? item;
        for (final candidate in items) {
          if (candidate.id == itemId) {
            item = candidate;
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
                backgroundColor: AppColors.cream,
                foregroundColor: AppColors.text,
                surfaceTintColor: Colors.transparent,
                pinned: true,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Container(
                      height: 340,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: AppColors.line),
                      ),
                      padding: const EdgeInsets.all(24),
                      child: CachedItemImage(
                        url: item.imageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      (resolvedItem.subtype ?? resolvedItem.category).toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 2,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _displayName(resolvedItem),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 30,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Category ${_capitalize(resolvedItem.category)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                    const SizedBox(height: 24),
                    _DetailPanel(item: resolvedItem),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      onPressed: () => _addToPlayground(context, ref, resolvedItem),
                      child: const Text('Add to Playground'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => context.go(
                        '/assistant',
                        extra: {'anchorItemId': resolvedItem.id},
                      ),
                      child: const Text('Style this Item'),
                    ),
                    const SizedBox(height: 34),
                    Text(
                      'Similar in your wardrobe',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 14),
                    _SimilarItemsStrip(items: items, current: resolvedItem),
                  ]),
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

  static String _displayName(WardrobeItem item) {
    if (item.color.isEmpty) return _capitalize(item.subtype ?? item.category);
    return '${_capitalize(item.color.first)} ${_capitalize(item.subtype ?? item.category)}';
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  void _addToPlayground(BuildContext context, WidgetRef ref, WardrobeItem item) {
    ref.read(stylingCanvasProvider.notifier).addWardrobeGarment(item);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to Playground')),
    );
    context.go('/playground');
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text(
          'This will permanently remove the item from your wardrobe.',
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
}

class _DetailPanel extends StatelessWidget {
  final WardrobeItem item;

  const _DetailPanel({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          _MetaLine(
            label: 'Type',
            value: item.subtype ?? 'Not set',
          ),
          _MetaLine(
            label: 'Category',
            value: WardrobeItemDetailScreen._capitalize(item.category),
          ),
          if (item.pattern?.isNotEmpty == true)
            _MetaLine(label: 'Pattern', value: item.pattern!),
          if (item.fit?.isNotEmpty == true)
            _MetaLine(label: 'Fit', value: item.fit!),
          if (item.color.isNotEmpty) ...[
            const SizedBox(height: 18),
            _ChipSection(
              title: 'Colors',
              values: item.color.map(WardrobeItemDetailScreen._capitalize).toList(),
            ),
          ],
          if (item.styleTags.isNotEmpty) ...[
            const SizedBox(height: 18),
            _ChipSection(
              title: 'Style tags',
              values: item.styleTags.map(WardrobeItemDetailScreen._capitalize).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final String label;
  final String value;

  const _MetaLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 1.6,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              WardrobeItemDetailScreen._capitalize(value),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChipSection extends StatelessWidget {
  final String title;
  final List<String> values;

  const _ChipSection({
    required this.title,
    required this.values,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.6,
                ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (value) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.lightMint,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SimilarItemsStrip extends StatelessWidget {
  final List<WardrobeItem> items;
  final WardrobeItem current;

  const _SimilarItemsStrip({
    required this.items,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final similar = items
        .where((i) => i.id != current.id && i.category == current.category)
        .take(4)
        .toList();

    if (similar.isEmpty) {
      return Text(
        'No similar items found.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
            ),
      );
    }

    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: similar.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = similar[index];
          return GestureDetector(
            onTap: () => context.push('/wardrobe/item/${item.id}'),
            child: SizedBox(
              width: 124,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.line),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: CachedItemImage(
                        url: item.imageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    WardrobeItemDetailScreen._capitalize(
                      item.subtype ?? item.category,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
