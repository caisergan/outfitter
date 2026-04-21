import 'package:fashion_app/core/models/slot_type.dart';

class GarmentCategoryFilter {
  final String label;
  final String backendCategory;

  const GarmentCategoryFilter({
    required this.label,
    required this.backendCategory,
  });
}

const garmentCategoryFilters = [
  GarmentCategoryFilter(label: 'Top', backendCategory: 'top'),
  GarmentCategoryFilter(label: 'Bottom', backendCategory: 'bottom'),
  GarmentCategoryFilter(label: 'Dress', backendCategory: 'dress'),
  GarmentCategoryFilter(label: 'Outwear', backendCategory: 'outerwear'),
  GarmentCategoryFilter(label: 'Shoes', backendCategory: 'footwear'),
  GarmentCategoryFilter(label: 'Accessories', backendCategory: 'accessory'),
  GarmentCategoryFilter(label: 'Swimwear', backendCategory: 'swimwear'),
  GarmentCategoryFilter(label: 'Underwear', backendCategory: 'underwear'),
];

GarmentCategoryFilter garmentCategoryForBackendCategory(String category) {
  for (final filter in garmentCategoryFilters) {
    if (filter.backendCategory == category) return filter;
  }
  return GarmentCategoryFilter(
    label: _titleizeCategory(category),
    backendCategory: category,
  );
}

GarmentCategoryFilter garmentCategoryForSlotType(SlotType type) {
  return switch (type) {
    SlotType.top => garmentCategoryForBackendCategory('top'),
    SlotType.bottom => garmentCategoryForBackendCategory('bottom'),
    SlotType.shoes => garmentCategoryForBackendCategory('footwear'),
    SlotType.accessory => garmentCategoryForBackendCategory('accessory'),
    SlotType.outerwear => garmentCategoryForBackendCategory('outerwear'),
    SlotType.bag => const GarmentCategoryFilter(
        label: 'Bag',
        backendCategory: 'bag',
      ),
  };
}

String _titleizeCategory(String category) {
  final words = category.replaceAll('_', ' ').split(' ');
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
