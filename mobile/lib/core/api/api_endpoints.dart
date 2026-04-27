class ApiEndpoints {
  // Auth
  static const signup = '/auth/signup';
  static const login = '/auth/login';
  static const authRefresh = '/auth/refresh';
  static const authMe = '/auth/me';

  // Catalog
  static const catalogSearch = '/catalog/search';
  static String catalogSimilar(String id) => '/catalog/similar/$id';

  // Wardrobe
  static const wardrobe = '/wardrobe';
  static const wardrobeTag = '/wardrobe/tag';
  static String wardrobeItem(String id) => '/wardrobe/$id';
  static const wardrobeUploadUrl = '/wardrobe/upload-url';

  // Outfits
  static const outfitsSuggest = '/outfits/suggest';
  static const outfits = '/outfits';
  static String outfit(String id) => '/outfits/$id';

  // Try-On
  static const tryonSubmit = '/tryon/submit';
  static String tryonStatus(String jobId) => '/tryon/status/$jobId';
}
