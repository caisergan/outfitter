import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/wardrobe_item.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_helpers.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../playground/providers/styling_canvas_provider.dart';
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
        for (final current in items) {
          if (current.id == itemId) {
            item = current;
            break;
          }
        }

        if (item == null) {
          return const Scaffold(
            backgroundColor: AppColors.cream,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final currentItem = item;

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
                    color: AppColors.secondaryText,
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 336,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.paper,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: CachedItemImage(
                      url: currentItem.imageUrl,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentItem.category.toUpperCase(),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.secondaryText,
                                  letterSpacing: 1.2,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currentItem.subtype ?? currentItem.category,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        _MetaRow(
                          icon: Icons.style_outlined,
                          label: currentItem.subtype ?? 'Item',
                        ),
                        _MetaRow(
                          icon: Icons.info_outline,
                          label: currentItem.category[0].toUpperCase() +
                              currentItem.category.substring(1),
                        ),
                        if (currentItem.pattern != null &&
                            currentItem.pattern!.isNotEmpty)
                          _MetaRow(
                            icon: Icons.grid_3x3_outlined,
                            label: currentItem.pattern!,
                          ),
                        if (currentItem.fit != null &&
                            currentItem.fit!.isNotEmpty)
                          _MetaRow(
                            icon: Icons.straighten_outlined,
                            label: currentItem.fit!,
                          ),
                        if (currentItem.styleTags.isNotEmpty)
                          _TagsRow(tags: currentItem.styleTags),
                        if (currentItem.color.isNotEmpty)
                          _ColorsRow(colors: currentItem.color),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    ElevatedButton(
                      onPressed: () =>
                          _addToPlayground(context, ref, currentItem),
                      child: const Text('Add to Playground'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      onPressed: () => context.go('/assistant', extra: {
                        'anchorItemId': currentItem.id,
                      }),
                      child: const Text('Style this Item'),
                    ),
                  ]),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 36, 20, 48),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(
                      'Similar in your Wardrobe',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 14),
                    _buildSimilarItems(context, items, currentItem),
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
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          foregroundColor: AppColors.text,
        ),
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
        .where((i) => i.id != current.id && i.category == current.category)
        .take(4)
        .toList();

    if (similar.isEmpty) {
      return Text(
        'No similar items found.',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.secondaryText,
            ),
      );
    }

    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: similar.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = similar[index];
          return GestureDetector(
            onTap: () => context.push('/wardrobe/item/${item.id}'),
            child: Container(
              width: 98,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.divider),
              ),
              child: CachedItemImage(
                url: item.imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }

  void _addToPlayground(BuildContext context, WidgetRef ref, WardrobeItem item) {
    ref.read(stylingCanvasProvider.notifier).addWardrobeGarment(item);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to Playground'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.go('/playground');
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item?'),
        content: Text(
          'This will permanently remove this item from your wardrobe.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.secondaryText,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF8A584F)),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
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

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaRow({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _TagsRow extends StatelessWidget {
  final List<String> tags;

  const _TagsRow({required this.tags});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Icon(Icons.label_outline, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags
                  .map(
                    (tag) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Text(
                        tag,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontSize: 12,
                            ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorsRow extends StatelessWidget {
  final List<String> colors;

  const _ColorsRow({required this.colors});

  Color _nameToColor(String name) {
    const map = {
      'red': Color(0xFFC77A6A),
      'blue': Color(0xFF899CB2),
      'green': Color(0xFF7F8D73),
      'yellow': Color(0xFFD8BF7A),
      'orange': Color(0xFFC89A67),
      'purple': Color(0xFF9A8DA9),
      'pink': Color(0xFFC99BA3),
      'black': Color(0xFF3F3A36),
      'white': Color(0xFFF0EBE3),
      'grey': Color(0xFFA39B92),
      'gray': Color(0xFFA39B92),
      'brown': Color(0xFF8B6A4F),
      'beige': Color(0xFFE8DDCB),
      'navy': Color(0xFF4C5970),
      'cream': Color(0xFFF4EFE6),
      'mint': Color(0xFFC8D5C6),
      'lavender': Color(0xFFBCAFC3),
      'olive': Color(0xFF7A7A56),
    };
    return map[name.toLowerCase()] ?? AppColors.backgroundSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Icon(
              Icons.water_drop_outlined,
              size: 18,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 8,
            children: colors
                .map(
                  (color) => Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: _nameToColor(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.divider,
                        width: 1.5,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
