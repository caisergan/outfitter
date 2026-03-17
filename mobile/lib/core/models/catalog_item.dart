import 'package:freezed_annotation/freezed_annotation.dart';

part 'catalog_item.freezed.dart';
part 'catalog_item.g.dart';

@freezed
class CatalogItem with _$CatalogItem {
  const factory CatalogItem({
    required String id,
    required String brand,
    required String category,
    String? subtype,
    required String name,
    required List<String> color,
    String? pattern,
    String? fit,
    @JsonKey(name: 'style_tags') required List<String> styleTags,
    @JsonKey(name: 'image_url') required String imageUrl,
    @JsonKey(name: 'product_url') String? productUrl,
  }) = _CatalogItem;

  factory CatalogItem.fromJson(Map<String, dynamic> json) =>
      _$CatalogItemFromJson(json);
}
