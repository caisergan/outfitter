import 'package:freezed_annotation/freezed_annotation.dart';

part 'outfit_models.freezed.dart';
part 'outfit_models.g.dart';

@freezed
class SlotItem with _$SlotItem {
  const factory SlotItem({
    required String id,
    required String name,
    required String brand,
    @JsonKey(name: 'image_url') required String imageUrl,
    @JsonKey(name: 'product_url') String? productUrl,
  }) = _SlotItem;

  factory SlotItem.fromJson(Map<String, dynamic> json) =>
      _$SlotItemFromJson(json);
}

@freezed
class OutfitSuggestion with _$OutfitSuggestion {
  const factory OutfitSuggestion({
    required Map<String, SlotItem> slots,
    @JsonKey(name: 'style_note') required String styleNote,
  }) = _OutfitSuggestion;

  factory OutfitSuggestion.fromJson(Map<String, dynamic> json) =>
      _$OutfitSuggestionFromJson(json);
}

@freezed
class SavedOutfit with _$SavedOutfit {
  const factory SavedOutfit({
    required String id,
    required String source,
    required Map<String, String> slots,
    @JsonKey(name: 'generated_image_url') String? generatedImageUrl,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _SavedOutfit;

  factory SavedOutfit.fromJson(Map<String, dynamic> json) =>
      _$SavedOutfitFromJson(json);
}

@freezed
class AssistantParams with _$AssistantParams {
  const factory AssistantParams({
    String? occasion,
    String? season,
    @JsonKey(name: 'color_preference') String? colorPreference,
    @Default('mix') String source,
  }) = _AssistantParams;

  factory AssistantParams.fromJson(Map<String, dynamic> json) =>
      _$AssistantParamsFromJson(json);
}
