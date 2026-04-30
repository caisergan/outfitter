import 'package:fashion_app/core/models/outfit_models.dart';

const String _base = 'assets/mockdata';

// Outfit 1
const String _img1 = '$_base/27077941-52-021-Photoroom.png';
const String _img2 = '$_base/27057939-50-021-Photoroom.png';
const String _img3 = '$_base/27047786-30-052-Photoroom.png';

// Outfit 2
const String _shirt = '$_base/SHIRT-Photoroom.png';
const String _pant  = '$_base/PANT-Photoroom.png';
const String _shoes = '$_base/SHOSS-Photoroom.png';

List<OutfitSuggestion> buildMockOutfits() {
  return [
    OutfitSuggestion(
      slots: {
        "top":    SlotItem(id: "mock_top",    imageUrl: _img1, name: "Mock Top",    brand: "Mock Brand"),
        "bottom": SlotItem(id: "mock_bottom", imageUrl: _img2, name: "Mock Bottom", brand: "Mock Brand"),
        "shoes":  SlotItem(id: "mock_shoes",  imageUrl: _img3, name: "Mock Shoes",  brand: "Mock Brand"),
      },
      styleNote: "Mock outfit 1",
    ),
    OutfitSuggestion(
      slots: {
        "top":    SlotItem(id: "mock2_top",    imageUrl: _shirt, name: "Mock Shirt", brand: "Mock Brand"),
        "bottom": SlotItem(id: "mock2_bottom", imageUrl: _pant,  name: "Mock Pant",  brand: "Mock Brand"),
        "shoes":  SlotItem(id: "mock2_shoes",  imageUrl: _shoes, name: "Mock Shoes", brand: "Mock Brand"),
      },
      styleNote: "Mock outfit 2",
    ),
  ];
}