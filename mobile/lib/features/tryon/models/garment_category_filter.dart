import 'package:fashion_app/core/models/slot_type.dart';

class GarmentCategoryFilter {
  final String label;
  final String? backendSlot;

  const GarmentCategoryFilter({
    required this.label,
    required this.backendSlot,
  });
}

const allGarmentCategoryFilter = GarmentCategoryFilter(
  label: 'All',
  backendSlot: null,
);

const garmentCategoryFilters = [
  GarmentCategoryFilter(label: 'Top', backendSlot: 'top'),
  GarmentCategoryFilter(label: 'Bottom', backendSlot: 'bottom'),
  GarmentCategoryFilter(label: 'Dress', backendSlot: 'dress'),
  GarmentCategoryFilter(label: 'Outerwear', backendSlot: 'outerwear'),
  GarmentCategoryFilter(label: 'Shoes', backendSlot: 'footwear'),
  GarmentCategoryFilter(label: 'Bag', backendSlot: 'bag'),
  GarmentCategoryFilter(label: 'Accessories', backendSlot: 'accessory'),
  GarmentCategoryFilter(label: 'Swimwear', backendSlot: 'swimwear'),
  GarmentCategoryFilter(label: 'Underwear', backendSlot: 'underwear'),
  GarmentCategoryFilter(label: 'Activewear', backendSlot: 'activewear'),
];

final garmentCategorySortOrder = {
  for (final entry in garmentCategoryFilters.indexed)
    if (entry.$2.backendSlot != null) entry.$2.backendSlot!: entry.$1,
};

GarmentCategoryFilter garmentCategoryForBackendSlot(String slot) {
  for (final filter in garmentCategoryFilters) {
    if (filter.backendSlot == slot) return filter;
  }
  return GarmentCategoryFilter(
    label: _titleizeSlot(slot),
    backendSlot: slot,
  );
}

GarmentCategoryFilter garmentCategoryForSlotType(SlotType type) {
  return switch (type) {
    SlotType.top => garmentCategoryForBackendSlot('top'),
    SlotType.bottom => garmentCategoryForBackendSlot('bottom'),
    SlotType.shoes => garmentCategoryForBackendSlot('footwear'),
    SlotType.accessory => garmentCategoryForBackendSlot('accessory'),
    SlotType.outerwear => garmentCategoryForBackendSlot('outerwear'),
    SlotType.bag => const GarmentCategoryFilter(
        label: 'Bag',
        backendSlot: 'bag',
      ),
  };
}

String _titleizeSlot(String slot) {
  final words = slot.replaceAll('_', ' ').split(' ');
  return words
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
