import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/wardrobe_provider.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/utils/error_helpers.dart';
import '../../../core/widgets/shared_widgets.dart';

class WardrobeItemDetailScreen extends ConsumerWidget {
  final String itemId;

  const WardrobeItemDetailScreen({required this.itemId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wardrobeState = ref.watch(wardrobeNotifierProvider);

    return wardrobeState.when(
      data: (items) {
        final item = items.firstWhere(
          (i) => i.id == itemId,
          orElse: () => throw Exception('Item not found'),
        );

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  background:
                      CachedItemImage(url: item.imageUrl, fit: BoxFit.cover),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      '${item.color.join(", ")} ${item.subtype ?? "Item"}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.category.toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTagsSection(context, item.styleTags),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () => context.go('/playground', extra: {
                        'slots': {item.category: item.id},
                      }),
                      child: const Text('Add to Playground'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => context.go('/assistant', extra: {
                        'anchorItemId': item.id,
                      }),
                      child: const Text('Style this Item'),
                    ),
                    const SizedBox(height: 48),
                    const Text(
                      'Similar in your Wardrobe',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    _buildSimilarWardrobeItems(items, item),
                    const SizedBox(height: 48),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, __) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(
          message: dioErrorToMessage(e),
          onRetry: () => ref.read(wardrobeNotifierProvider.notifier).fetch(),
        ),
      ),
    );
  }

  Widget _buildTagsSection(BuildContext context, List<String> tags) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags
          .map((t) => Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  t,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildSimilarWardrobeItems(List<dynamic> items, dynamic currentItem) {
    final similar = items
        .where(
            (i) => i.id != currentItem.id && i.category == currentItem.category)
        .take(4)
        .toList();

    if (similar.isEmpty) return const Text('No similar items found.');

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: similar.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = similar[index];
          return GestureDetector(
            onTap: () => context.push('/wardrobe/item/${item.id}'),
            child: Container(
              width: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedItemImage(url: item.imageUrl),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: const Text(
            'This will permanently remove this item from your wardrobe.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(wardrobeNotifierProvider.notifier).deleteItem(itemId);
        if (context.mounted) context.pop();
      } catch (e) {
        if (context.mounted) showErrorSnackbar(context, dioErrorToMessage(e));
      }
    }
  }
}
