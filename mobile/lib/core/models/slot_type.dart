/// All slot types in an outfit, mapped to backend category strings.
enum SlotType {
  top,
  bottom,
  shoes,
  accessory,
  outerwear,
  bag;

  String get categoryString => name;

  String get displayName => switch (this) {
        SlotType.top => 'Top',
        SlotType.bottom => 'Bottom',
        SlotType.shoes => 'Shoes',
        SlotType.accessory => 'Accessory',
        SlotType.outerwear => 'Outerwear',
        SlotType.bag => 'Bag',
      };

  bool get isRequired =>
      this == SlotType.top ||
      this == SlotType.bottom ||
      this == SlotType.shoes;
}
