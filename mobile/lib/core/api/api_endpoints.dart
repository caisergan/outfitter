class ApiEndpoints {
  // Auth
  static const signup = '/auth/signup';
  static const login = '/auth/login';
  static const authRefresh = '/auth/refresh';
  static const authMe = '/auth/me';

  // Catalog
  static const catalogSearch = '/catalog/search';
  static const catalogFilterOptions = '/catalog/filter-options';
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

  // Try-On (gpt-image-2 editorial generation)
  static const tryonSystemPrompt = '/tryon/system-prompt';
  static const tryonTemplates = '/tryon/templates';
  static const tryonPersonas = '/tryon/personas';
  static const tryonGenerate = '/tryon/generate-image';
  static const tryonRuns = '/tryon/runs';
  static String tryonRun(String runId) => '/tryon/runs/$runId';

  // Catalog single-item lookup (used for reproducing past tryon runs)
  static String catalogItem(String itemId) => '/catalog/items/$itemId';
}
