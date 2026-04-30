class CatalogFilterOptions {
  const CatalogFilterOptions({
    required this.categories,
    required this.brands,
    required this.genders,
    required this.fits,
    required this.colors,
    required this.styleTags,
    required this.subtypes,
    required this.subtypesByCategory,
  });

  final List<String> categories;
  final List<String> brands;
  final List<String> genders;
  final List<String> fits;
  final List<String> colors;
  final List<String> styleTags;
  final List<String> subtypes;
  final Map<String, List<String>> subtypesByCategory;

  factory CatalogFilterOptions.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(Object? value) {
      return (value as List? ?? const []).whereType<String>().toList();
    }

    final rawSubtypeMap =
        json['subtypes_by_category'] as Map<String, dynamic>? ?? const {};

    return CatalogFilterOptions(
      categories: parseStringList(json['categories']),
      brands: parseStringList(json['brands']),
      genders: parseStringList(json['genders']),
      fits: parseStringList(json['fits']),
      colors: parseStringList(json['colors']),
      styleTags: parseStringList(json['style_tags']),
      subtypes: parseStringList(json['subtypes']),
      subtypesByCategory: {
        for (final entry in rawSubtypeMap.entries)
          entry.key: parseStringList(entry.value),
      },
    );
  }
}
