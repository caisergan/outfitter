import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/slot_type.dart';
import 'package:fashion_app/core/models/catalog_item.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/features/discover/data/catalog_repository.dart';
import 'package:fashion_app/features/wardrobe/providers/wardrobe_provider.dart';
import 'package:fashion_app/features/playground/providers/slot_builder_provider.dart';

class ItemBrowserSheet extends ConsumerStatefulWidget {
  final SlotType type;
  final Function(CatalogItem) onItemSelected;

  const ItemBrowserSheet({
    required this.type,
    required this.onItemSelected,
    super.key,
  });

  @override
  ConsumerState<ItemBrowserSheet> createState() => _ItemBrowserSheetState();
}

class _ItemBrowserSheetState extends ConsumerState<ItemBrowserSheet> {
  String _selectedCategory = 'All Styles';

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
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Garment Selection',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                    const SizedBox(width: 12),
                    // Item Count Badge Mock
                    _buildItemCountBadge('248 Items'),
                    const Spacer(),
                    Icon(Icons.tune, color: Colors.grey.shade400),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Category Filters
              _buildCategoryFilters(),
              const SizedBox(height: 16),
              // Grid View
              Expanded(child: _buildItemGrid(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildItemCountBadge(String count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F0FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        count,
        style: const TextStyle(
          color: Color(0xFF1D5CE0),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final categories = ['All Styles', 'Outerwear', 'Knitwear', 'Tops', 'Bottoms'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = cat),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1D5CE0) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemGrid(ScrollController scrollController) {
    final currentSlots = ref.watch(slotBuilderProvider).slots;
    final selectedInSlot = currentSlots[widget.type];

    return FutureBuilder<List<CatalogItem>>(
      future: ref.read(catalogRepositoryProvider).search(
        category: widget.type.categoryString,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];

        return GridView.builder(
          controller: scrollController,
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
            final isSelected = selectedInSlot?.id == item.id;

            return GestureDetector(
              onTap: () {
                ref.read(slotBuilderProvider.notifier).setSlot(widget.type, item);
                Navigator.pop(context);
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(16),
                            border: isSelected
                                ? Border.all(color: const Color(0xFF1D5CE0), width: 2)
                                : null,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CachedItemImage(url: item.imageUrl),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1D5CE0),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.name.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                      color: isSelected ? const Color(0xFF1D5CE0) : Colors.black87,
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
}
