import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/catalog_item.dart';
import 'package:fashion_app/core/models/slot_type.dart';
import 'package:fashion_app/core/theme/app_colors.dart';
import 'package:fashion_app/core/widgets/shared_widgets.dart';
import 'package:fashion_app/features/discover/data/catalog_repository.dart';
import 'package:fashion_app/features/playground/models/garment_category_filter.dart';
import 'package:fashion_app/features/playground/providers/slot_builder_provider.dart';

class ItemBrowserSheet extends ConsumerStatefulWidget {
  final SlotType? type;
  final Function(CatalogItem) onItemSelected;
  final bool updateSlotOnSelect;
  final String? initialCategory;

  const ItemBrowserSheet({
    this.type,
    required this.onItemSelected,
    this.updateSlotOnSelect = true,
    this.initialCategory,
    super.key,
  }) : assert(!updateSlotOnSelect || type != null);

  @override
  ConsumerState<ItemBrowserSheet> createState() => _ItemBrowserSheetState();
}

class _ItemBrowserSheetState extends ConsumerState<ItemBrowserSheet> {
  late GarmentCategoryFilter _selectedCategory;
  late Future<List<CatalogItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory == null
        ? widget.type == null
            ? garmentCategoryFilters.first
            : garmentCategoryForSlotType(widget.type!)
        : garmentCategoryForBackendCategory(widget.initialCategory!);
    _itemsFuture = _searchSelectedCategory();
  }

  List<GarmentCategoryFilter> get _categoryFilters {
    final hasSelectedCategory = garmentCategoryFilters.any(
      (filter) => filter.backendCategory == _selectedCategory.backendCategory,
    );
    if (hasSelectedCategory) return garmentCategoryFilters;
    return [_selectedCategory, ...garmentCategoryFilters];
  }

  Future<List<CatalogItem>> _searchSelectedCategory() {
    return ref.read(catalogRepositoryProvider).search(
          category: _selectedCategory.backendCategory,
        );
  }

  void _selectCategory(GarmentCategoryFilter filter) {
    setState(() {
      _selectedCategory = filter;
      _itemsFuture = _searchSelectedCategory();
    });
  }

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
                  'Shop catalog',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Browse by category and place pieces directly onto the canvas.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                ),
                const SizedBox(height: 18),
                _buildCategoryFilters(),
                const SizedBox(height: 14),
                Expanded(child: _buildItemGrid(scrollController)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categoryFilters.map((filter) {
          final isSelected =
              _selectedCategory.backendCategory == filter.backendCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter.label),
              selected: isSelected,
              onSelected: (_) => _selectCategory(filter),
              selectedColor: AppColors.surfaceAlt,
              backgroundColor: AppColors.surface,
              side: BorderSide(
                color: isSelected ? AppColors.borderStrong : AppColors.border,
              ),
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected ? AppColors.text : AppColors.textMuted,
                  ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemGrid(ScrollController scrollController) {
    final selectedInSlot = widget.updateSlotOnSelect
        ? ref.watch(slotBuilderProvider).slots[widget.type]
        : null;

    return FutureBuilder<List<CatalogItem>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Could not load garments.',
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
              'No garments found for this category.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          );
        }

        return GridView.builder(
          controller: scrollController,
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
            final isSelected = selectedInSlot?.id == item.id;

            return GestureDetector(
              onTap: () {
                if (widget.updateSlotOnSelect && widget.type != null) {
                  ref.read(slotBuilderProvider.notifier).setSlot(widget.type!, item);
                }
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
                        border: Border.all(
                          color: isSelected
                              ? AppColors.borderStrong
                              : Colors.transparent,
                          width: 1.5,
                        ),
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
                    item.name.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color:
                              isSelected ? AppColors.text : AppColors.textMuted,
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
}
