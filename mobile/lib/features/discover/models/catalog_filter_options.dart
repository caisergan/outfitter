class CatalogFilterOptions {
  final List<String> categories;
  final List<String> subtypes;
  final List<String> brands;
  final List<String> genders;
  final List<String> fits;
  final List<String> patterns;
  final List<String> colors;
  final List<String> styleTags;

  const CatalogFilterOptions({
    required this.categories,
    required this.subtypes,
    required this.brands,
    required this.genders,
    required this.fits,
    required this.patterns,
    required this.colors,
    required this.styleTags,
  });

  const CatalogFilterOptions.empty()
      : categories = const [],
        subtypes = const [],
        brands = const [],
        genders = const [],
        fits = const [],
        patterns = const [],
        colors = const [],
        styleTags = const [];

  factory CatalogFilterOptions.fromJson(Map<String, dynamic> json) {
    List<String> parseList(String key) {
      final raw = json[key] as List<dynamic>? ?? const [];
      return raw.map((entry) => entry.toString()).toList(growable: false);
    }

    return CatalogFilterOptions(
      categories: parseList('categories'),
      subtypes: parseList('subtypes'),
      brands: parseList('brands'),
      genders: parseList('genders'),
      fits: parseList('fits'),
      patterns: parseList('patterns'),
      colors: parseList('colors'),
      styleTags: parseList('style_tags'),
    );
  }

  bool get hasAdvancedOptions =>
      brands.isNotEmpty ||
      fits.isNotEmpty ||
      patterns.isNotEmpty ||
      colors.isNotEmpty ||
      styleTags.isNotEmpty;
}
