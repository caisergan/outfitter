import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/slot_type.dart';
import 'package:fashion_app/core/models/catalog_item.dart';

typedef SlottedItem = CatalogItem;

class OutfitSlots {
  final Map<SlotType, SlottedItem?> slots;
  const OutfitSlots(this.slots);

  OutfitSlots copyWithSlot(SlotType type, SlottedItem? item) =>
      OutfitSlots({...slots, type: item});

  bool get isValid =>
      slots[SlotType.top] != null &&
      slots[SlotType.bottom] != null &&
      slots[SlotType.shoes] != null;

  Map<String, String> get slotIds => {
        for (final entry in slots.entries)
          if (entry.value != null) entry.key.categoryString: entry.value!.id,
      };

  static OutfitSlots empty() => OutfitSlots({
        for (final type in SlotType.values) type: null,
      });
}

class SlotBuilderNotifier extends StateNotifier<OutfitSlots> {
  SlotBuilderNotifier() : super(OutfitSlots.empty());

  void setSlot(SlotType type, SlottedItem? item) {
    state = state.copyWithSlot(type, item);
  }

  void prefill(Map<String, String> itemIds, List<SlottedItem> allItems) {
    final itemMap = {for (final item in allItems) item.id: item};
    var current = OutfitSlots.empty();
    for (final entry in itemIds.entries) {
      try {
        final slotType = SlotType.values
            .firstWhere((t) => t.categoryString == entry.key);
        final item = itemMap[entry.value];
        if (item != null) current = current.copyWithSlot(slotType, item);
      } catch (_) {}
    }
    state = current;
  }

  void clearSlot(SlotType type) {
    state = state.copyWithSlot(type, null);
  }

  void clearAll() {
    state = OutfitSlots.empty();
  }
}

final slotBuilderProvider =
    StateNotifierProvider.autoDispose<SlotBuilderNotifier, OutfitSlots>(
        (_) => SlotBuilderNotifier());
