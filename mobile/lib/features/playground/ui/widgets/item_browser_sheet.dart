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
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Garment Selection',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    const Icon(Icons.tune, color: AppColors.secondaryText),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _buildCategoryFilters(),
              const SizedBox(height: 14),
              Expanded(child: _buildItemGrid(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: _categoryFilters.map((filter) {
          final isSelected =
              _selectedCategory.backendCategory == filter.backendCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _selectCategory(filter),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.paper,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.divider,
                  ),
                ),
                child: Text(
                  filter.label,
                  style: TextStyle(
                    color:
                        isSelected ? AppColors.background : AppColors.text,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
          return const Center(
            child: Text(
              'Could not load garments.',
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
              'No garments found for this category.',
              style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        return GridView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 20,
            childAspectRatio: 0.72,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final isSelected = selectedInSlot?.id == item.id;

            return GestureDetector(
              onTap: () {
                if (widget.updateSlotOnSelect && widget.type != null) {
                  ref
                      .read(slotBuilderProvider.notifier)
                      .setSlot(widget.type!, item);
                }
                widget.onItemSelected(item);
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
                            color: AppColors.paper,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.divider,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CachedItemImage(url: item.imageUrl),
                        ),
                        if (isSelected)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                color: AppColors.background,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.name.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 10,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.text,
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
