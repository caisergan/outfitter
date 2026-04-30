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

  // Try-On
  static const tryonSubmit = '/tryon/submit';
  static String tryonStatus(String jobId) => '/tryon/status/$jobId';

  // Playground (gpt-image-2 editorial generation)
  static const playgroundSystemPrompt = '/playground/system-prompt';
  static const playgroundTemplates = '/playground/templates';
  static const playgroundPersonas = '/playground/personas';
  static const playgroundGenerate = '/playground/generate-image';
  static const playgroundRuns = '/playground/runs';
  static String playgroundRun(String runId) => '/playground/runs/$runId';

  // Catalog single-item lookup (used for reproducing past playground runs)
  static String catalogItem(String itemId) => '/catalog/items/$itemId';
}
