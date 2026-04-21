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
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'My Wardrobe',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.text,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.checkroom_outlined,
                      color: AppColors.text.withValues(alpha: 0.5),
                    ),
                  ],
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
          return const Center(
            child: Text(
              'Could not load your wardrobe.',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Center(
            child: Text(
              'Your wardrobe is empty.',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        return GridView.builder(
          controller: widget.scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 20,
            childAspectRatio: 0.75,
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
                        color: AppColors.lightMint.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.lightMint),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: CachedItemImage(url: item.imageUrl),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _wardrobeItemLabel(item).toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
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
    final subtype = item.subtype ?? item.category;
    return [color, subtype].whereType<String>().join(' ');
  }
}
