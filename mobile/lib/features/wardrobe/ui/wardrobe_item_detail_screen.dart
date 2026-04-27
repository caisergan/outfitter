import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/wardrobe_provider.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/utils/error_helpers.dart';
import '../../../core/widgets/shared_widgets.dart';
import '/core/models/wardrobe_item.dart';
import '/core/theme/app_colors.dart';
import '/features/playground/providers/styling_canvas_provider.dart';

class WardrobeItemDetailScreen extends ConsumerWidget {
  final String itemId;

  const WardrobeItemDetailScreen({required this.itemId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wardrobeState = ref.watch(wardrobeNotifierProvider);

    return wardrobeState.when(
      data: (items) {
        final WardrobeItem? item = items.firstWhereOrNull(
              (i) => i.id == itemId,
        );

        // Item was just deleted — navigator is popping, render nothing
        if (item == null) {
          return const Scaffold(
            backgroundColor: AppColors.cream,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.mint),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.cream,
          body: CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────────────────
              SliverAppBar(
                backgroundColor: AppColors.cream,
                foregroundColor: AppColors.text,
                surfaceTintColor: Colors.transparent,
                pinned: true,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.text.withOpacity(0.6),
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ),

              // ── Hero Image ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      height: 320,
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: CachedItemImage(
                        url: item.imageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Name + Edit ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.subtype ?? item.category,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          // TODO: open edit sheet
                        },
                        child: Icon(
                          Icons.edit_outlined,
                          size: 20,
                          color: AppColors.text.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Metadata Card ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.lightMint.withOpacity(0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.mint.withOpacity(0.07),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _MetaRow(
                          icon: Icons.style_outlined,
                          label: item.subtype ?? 'Item',
                          showDivider: true,
                        ),
                        _MetaRow(
                          icon: Icons.info_outline,
                          label: item.category[0].toUpperCase() +
                              item.category.substring(1),
                          showDivider: true,
                        ),
                        if (item.pattern != null && item.pattern!.isNotEmpty)
                          _MetaRow(
                            icon: Icons.grid_3x3_outlined,
                            label: item.pattern!,
                            showDivider: true,
                          ),
                        if (item.fit != null && item.fit!.isNotEmpty)
                          _MetaRow(
                            icon: Icons.straighten_outlined,
                            label: item.fit!,
                            showDivider: item.styleTags.isNotEmpty ||
                                item.color.isNotEmpty,
                          ),
                        if (item.styleTags.isNotEmpty)
                          _TagsRow(tags: item.styleTags),
                        if (item.color.isNotEmpty)
                          _ColorsRow(colors: item.color),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Action Buttons ───────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.blush,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => _addToPlayground(context, ref, item),
                      child: const Text(
                        'Add to Playground',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blush,
                        minimumSize: const Size.fromHeight(50),
                        side: BorderSide(
                            color: AppColors.mint.withOpacity(0.8),
                            width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => context.go('/assistant', extra: {
                        'anchorItemId': item.id,
                      }),
                      child: const Text(
                        'Style this Item',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ]),
                ),
              ),

              // ── Similar Items ────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 36, 20, 48),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const Text(
                      'Similar in your Wardrobe',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSimilarItems(context, items, item),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.mint),
        ),
      ),
      error: (e, __) => Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          foregroundColor: AppColors.text,
        ),
        body: ErrorView(
          message: dioErrorToMessage(e),
          onRetry: () =>
              ref.read(wardrobeNotifierProvider.notifier).fetch(),
        ),
      ),
    );
  }

  Widget _buildSimilarItems(
      BuildContext context, List<WardrobeItem> items, WardrobeItem current) {
    final similar = items
        .where((i) => i.id != current.id && i.category == current.category)
        .take(4)
        .toList();

    if (similar.isEmpty) {
      return Text(
        'No similar items found.',
        style: TextStyle(color: AppColors.text.withOpacity(0.4)),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: similar.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final s = similar[index];
          return GestureDetector(
            onTap: () => context.push('/wardrobe/item/${s.id}'),
            child: Container(
              width: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.lightMint.withOpacity(0.6)),
              ),
              padding: const EdgeInsets.all(6),
              clipBehavior: Clip.antiAlias,
              child: CachedItemImage(
                url: s.imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );
  }

  void _addToPlayground(
      BuildContext context,
      WidgetRef ref,
      WardrobeItem item,
      ) {
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
        backgroundColor: Colors.white,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Item?',
          style: TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.text),
        ),
        content: Text(
          'This will permanently remove this item from your wardrobe.',
          style: TextStyle(color: AppColors.text.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.text.withOpacity(0.5))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete',
                style: TextStyle(fontWeight: FontWeight.w700)),
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

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool showDivider;

  const _MetaRow({
    required this.icon,
    required this.label,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.mint),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.text,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.text.withOpacity(0.25)),
            ],
          ),
        ),
        if (showDivider)
          Divider(
              height: 1,
              indent: 48,
              color: AppColors.lightMint.withOpacity(0.5)),
      ],
    );
  }
}

class _TagsRow extends StatelessWidget {
  final List<String> tags;

  const _TagsRow({required this.tags});

  static const _pillColors = [
    Color(0xFFFFB7C5), // pink
    Color(0xFFB5D5F5), // sky blue
    Color(0xFFB5EAD7), // soft green
    Color(0xFFFFDFB5), // peach
    Color(0xFFD4B5F5), // lavender
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(
            height: 1,
            indent: 48,
            color: AppColors.lightMint.withOpacity(0.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.label_outline,
                  size: 20, color: AppColors.mint),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: List.generate(tags.length, (i) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _pillColors[i % _pillColors.length],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tags[i],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.text.withOpacity(0.25)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorsRow extends StatelessWidget {
  final List<String> colors;

  const _ColorsRow({required this.colors});

  Color _nameToColor(String name) {
    const map = {
      'red': Color(0xFFE74C3C),
      'blue': Color(0xFF7AAACE),
      'green': Color(0xFF27AE60),
      'yellow': Color(0xFFF1C40F),
      'orange': Color(0xFFE67E22),
      'purple': Color(0xFF9B59B6),
      'pink': Color(0xFFFF6FAB),
      'black': Color(0xFF2C2C2C),
      'white': Color(0xFFF5F5F5),
      'grey': Color(0xFF95A5A6),
      'gray': Color(0xFF95A5A6),
      'brown': Color(0xFF8B6347),
      'beige': Color(0xFFF5F0E8),
      'navy': Color(0xFF1B2A4A),
      'cream': Color(0xFFF7F8F0),
      'mint': Color(0xFFbbe2ff),
      'lavender': Color(0xFFC7CEEA),
      'olive': Color(0xFF6B7C3F),
    };
    return map[name.toLowerCase()] ?? AppColors.lightMint;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Divider(
            height: 1,
            indent: 48,
            color: AppColors.lightMint.withOpacity(0.5)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.water_drop_outlined,
                  size: 20, color: AppColors.mint),
              const SizedBox(width: 12),
              Wrap(
                spacing: 8,
                children: colors.map((c) {
                  return Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: _nameToColor(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.lightMint.withOpacity(0.6),
                        width: 1.5,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.text.withOpacity(0.25)),
            ],
          ),
        ),
      ],
    );
  }
}