import 'package:fashion_app/core/models/catalog_item.dart';

class CanvasGarment {
  final String id;
  final CatalogItem item;
  final double x;
  final double y;
  final double scale;
  final double rotation;

  const CanvasGarment({
    required this.id,
    required this.item,
    required this.x,
    required this.y,
    required this.scale,
    required this.rotation,
  });

  CanvasGarment copyWith({
    CatalogItem? item,
    double? x,
    double? y,
    double? scale,
    double? rotation,
  }) {
    return CanvasGarment(
      id: id,
      item: item ?? this.item,
      x: x ?? this.x,
      y: y ?? this.y,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'item': item.toJson(),
      'x': x,
      'y': y,
      'scale': scale,
      'rotation': rotation,
    };
  }

  factory CanvasGarment.fromJson(Map<String, dynamic> json) {
    return CanvasGarment(
      id: json['id'] as String,
      item: CatalogItem.fromJson(json['item'] as Map<String, dynamic>),
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      scale: (json['scale'] as num).toDouble(),
      rotation: (json['rotation'] as num).toDouble(),
    );
  }
}

class SavedStylingCanvasOutfit {
  final String id;
  final String title;
  final List<CanvasGarment> garments;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SavedStylingCanvasOutfit({
    required this.id,
    required this.title,
    required this.garments,
    required this.createdAt,
    required this.updatedAt,
  });

  SavedStylingCanvasOutfit copyWith({
    String? title,
    List<CanvasGarment>? garments,
    DateTime? updatedAt,
  }) {
    return SavedStylingCanvasOutfit(
      id: id,
      title: title ?? this.title,
      garments: garments ?? this.garments,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'garments': garments.map((garment) => garment.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory SavedStylingCanvasOutfit.fromJson(Map<String, dynamic> json) {
    return SavedStylingCanvasOutfit(
      id: json['id'] as String,
      title: json['title'] as String,
      garments: (json['garments'] as List)
          .map((entry) => CanvasGarment.fromJson(entry as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
