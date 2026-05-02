import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/wardrobe_item.dart';
import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/features/wardrobe/data/wardrobe_repository.dart';

class WardrobeBrowserSheet extends StatelessWidget {
  final ValueChanged<WardrobeItem> onItemSelected;

  const WardrobeBrowserSheet({
    required this.onItemSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My wardrobe',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a saved piece and place it onto the current look.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _WardrobeGrid(
                    scrollController: scrollController,
                    onItemSelected: onItemSelected,
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

class _WardrobeGrid extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final ValueChanged<WardrobeItem> onItemSelected;

  const _WardrobeGrid({
    required this.scrollController,
    required this.onItemSelected,
  });

  @override
  ConsumerState<_WardrobeGrid> createState() => _WardrobeGridState();
}

class _WardrobeGridState extends ConsumerState<_WardrobeGrid> {
  late Future<List<WardrobeItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = ref.read(wardrobeRepositoryProvider).fetchAll();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WardrobeItem>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load your wardrobe.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(
            child: Text(
              'Your wardrobe is empty.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          );
        }

        return GridView.builder(
          controller: widget.scrollController,
          padding: const EdgeInsets.only(top: 6, bottom: 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 14,
            mainAxisSpacing: 18,
            childAspectRatio: 0.68,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: () {
                widget.onItemSelected(item);
                Navigator.pop(context);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: CachedItemImage(
                        url: item.imageUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _wardrobeItemLabel(item).toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _wardrobeItemLabel(WardrobeItem item) {
    final color = item.color.isEmpty ? null : item.color.join(', ');
    final label = item.subcategory ?? item.category ?? item.slot;
    return [color, label].whereType<String>().join(' ');
  }
}
