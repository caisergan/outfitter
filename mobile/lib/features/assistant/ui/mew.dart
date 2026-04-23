import 'package:fashion_app/core/models/outfit_models.dart';

const String mockCatImage ="https://www.vhv.rs/dpng/d/410-4101929_transparent-crazy-cat-clipart-funny-cat-stickers-whatsapp.png";
List<OutfitSuggestion> buildMockOutfits() {
  final item = SlotItem(
    id: "mock",
    imageUrl: mockCatImage,
    name: "Mock Item",
    brand: "Mock Brand",
  );

  final slots = {
    "top": item,
    "bottom": item,
    "shoes": item,
    "accessory": item,
  };

  return List.generate(
    10,
        (i) => OutfitSuggestion(
      slots: slots,
      styleNote: "Mock outfit ${i + 1}",
    ),
  );
}