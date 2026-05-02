class CatalogFilterOptions {
  const CatalogFilterOptions({
    required this.slots,
    required this.categories,
    required this.subcategories,
    required this.brands,
    required this.genders,
    required this.fits,
    required this.colors,
    required this.patterns,
    required this.styleTags,
    required this.occasionTags,
    required this.categoriesBySlot,
    required this.subcategoriesByCategory,
  });

  final List<String> slots;
  final List<String> categories;
  final List<String> subcategories;
  final List<String> brands;
  final List<String> genders;
  final List<String> fits;
  final List<String> colors;
  final List<String> patterns;
  final List<String> styleTags;
  final List<String> occasionTags;
  final Map<String, List<String>> categoriesBySlot;
  final Map<String, List<String>> subcategoriesByCategory;

  factory CatalogFilterOptions.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(Object? value) {
      return (value as List? ?? const []).whereType<String>().toList();
    }

    Map<String, List<String>> parseMap(Object? value) {
      final raw = value as Map<String, dynamic>? ?? const {};
      return {
        for (final entry in raw.entries) entry.key: parseStringList(entry.value),
      };
    }

    return CatalogFilterOptions(
      slots: parseStringList(json['slots']),
      categories: parseStringList(json['categories']),
      subcategories: parseStringList(json['subcategories']),
      brands: parseStringList(json['brands']),
      genders: parseStringList(json['genders']),
      fits: parseStringList(json['fits']),
      colors: parseStringList(json['colors']),
      patterns: parseStringList(json['patterns']),
      styleTags: parseStringList(json['style_tags']),
      occasionTags: parseStringList(json['occasion_tags']),
      categoriesBySlot: parseMap(json['categories_by_slot']),
      subcategoriesByCategory: parseMap(json['subcategories_by_category']),
    );
  }
}
