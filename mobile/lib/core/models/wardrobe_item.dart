import 'package:freezed_annotation/freezed_annotation.dart';

part 'wardrobe_item.freezed.dart';
part 'wardrobe_item.g.dart';

@freezed
class WardrobeItem with _$WardrobeItem {
  const factory WardrobeItem({
    required String id,
    @JsonKey(name: 'user_id') required String userId,
    required String slot,
    String? category,
    String? subcategory,
    required List<String> color,
    List<String>? pattern,
    String? fit,
    @JsonKey(name: 'style_tags') required List<String> styleTags,
    @JsonKey(name: 'occasion_tags') List<String>? occasionTags,
    @JsonKey(name: 'image_url') required String imageUrl,
    @JsonKey(name: 'times_used') required int timesUsed,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _WardrobeItem;

  factory WardrobeItem.fromJson(Map<String, dynamic> json) =>
      _$WardrobeItemFromJson(json);
}

@freezed
class WardrobeTagResult with _$WardrobeTagResult {
  const factory WardrobeTagResult({
    required String slot,
    String? category,
    String? subcategory,
    required List<String> color,
    List<String>? pattern,
    String? fit,
    @JsonKey(name: 'style_tags') required List<String> styleTags,
    @JsonKey(name: 'occasion_tags') List<String>? occasionTags,
    required double confidence,
    @JsonKey(name: 'image_url') required String imageUrl,
  }) = _WardrobeTagResult;

  factory WardrobeTagResult.fromJson(Map<String, dynamic> json) =>
      _$WardrobeTagResultFromJson(json);
}

@freezed
class CreateWardrobeItemRequest with _$CreateWardrobeItemRequest {
  const factory CreateWardrobeItemRequest({
    required String slot,
    String? category,
    String? subcategory,
    required List<String> color,
    List<String>? pattern,
    String? fit,
    @JsonKey(name: 'style_tags') required List<String> styleTags,
    @JsonKey(name: 'occasion_tags') List<String>? occasionTags,
    @JsonKey(name: 'image_url') required String imageUrl,
  }) = _CreateWardrobeItemRequest;

  factory CreateWardrobeItemRequest.fromJson(Map<String, dynamic> json) =>
      _$CreateWardrobeItemRequestFromJson(json);
}
