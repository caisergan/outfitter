# Flutter Technical Documentation — Fashion App

**Version:** 1.0 | **Date:** 2026-03-07 | **Platform:** iOS + Android

> This document covers the Flutter mobile app layer only. Backend, database, and AI service implementation are documented separately. All API contracts referenced here are stable and backend is assumed to be running.

---

## Table of Contents

1. [Project Setup](#1-project-setup)
2. [App Architecture](#2-app-architecture)
3. [Navigation](#3-navigation)
4. [State Management (Riverpod)](#4-state-management-riverpod)
5. [API Client & Data Layer](#5-api-client--data-layer)
6. [Authentication Flow](#6-authentication-flow)
7. [Feature: Discover Tab](#7-feature-discover-tab)
8. [Feature: Playground Tab](#8-feature-playground-tab)
9. [Feature: Assistant Tab](#9-feature-assistant-tab)
10. [Feature: Wardrobe Tab](#10-feature-wardrobe-tab)
11. [Shared Components & Widgets](#11-shared-components--widgets)
12. [Image Handling & Upload](#12-image-handling--upload)
13. [Try-On Polling Flow](#13-try-on-polling-flow)
14. [Error Handling](#14-error-handling)
15. [Performance Guidelines](#15-performance-guidelines)
16. [Environment Configuration](#16-environment-configuration)
17. [Data Models (Dart)](#17-data-models-dart)
18. [API Endpoint Reference (Flutter-Facing)](#18-api-endpoint-reference-flutter-facing)

---

## 1. Project Setup

### Prerequisites

- Flutter SDK `>=3.19.0`
- Dart `>=3.3.0`
- Xcode 15+ (iOS)
- Android Studio / NDK r26+ (Android)
- A running backend at a reachable base URL

### pubspec.yaml

```yaml
name: fashion_app
description: AI-powered outfit builder and try-on app.
version: 1.0.0+1

environment:
  sdk: ">=3.3.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter

  # Networking
  dio: ^5.4.0

  # State management
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.5

  # Navigation
  go_router: ^13.2.0

  # Image
  image_picker: ^1.0.7
  cached_network_image: ^3.3.1

  # Storage
  shared_preferences: ^2.2.2
  flutter_secure_storage: ^9.0.0

  # Env
  flutter_dotenv: ^5.1.0

  # Utilities
  freezed_annotation: ^2.4.1
  json_annotation: ^4.9.0
  uuid: ^4.3.3

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.9
  freezed: ^2.5.2
  json_serializable: ^6.8.0
  riverpod_generator: ^2.4.0
  flutter_lints: ^3.0.0
```

### Getting Started

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# iOS
cd ios && pod install && cd ..
flutter run -d ios

# Android
flutter run -d android
```

---

## 2. App Architecture

The app follows a layered architecture:

```
lib/
├── main.dart                    # Entry point, ProviderScope, env init
├── app.dart                     # MaterialApp.router + GoRouter setup
├── core/
│   ├── api/
│   │   ├── api_client.dart      # Dio instance, interceptors, base URL
│   │   └── api_endpoints.dart   # All endpoint string constants
│   ├── auth/
│   │   ├── auth_provider.dart   # Riverpod auth state
│   │   └── token_storage.dart   # Secure token read/write
│   ├── models/                  # Freezed data models (shared)
│   └── widgets/                 # Shared UI components
├── features/
│   ├── discover/
│   │   ├── data/                # Repository + DTOs
│   │   ├── providers/           # Riverpod providers
│   │   └── ui/                  # Screens + widgets
│   ├── playground/
│   ├── assistant/
│   └── wardrobe/
└── router.dart                  # go_router definition
```

**Layer responsibilities:**

- `data/` — raw API calls, JSON parsing, repository pattern
- `providers/` — Riverpod providers exposing state and async operations
- `ui/` — pure Flutter widgets consuming providers via `ref.watch`/`ref.read`

---

## 3. Navigation

### Router Setup (`lib/router.dart`)

```dart
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/discover',
  redirect: (context, state) {
    // Redirect to /login if not authenticated
    final isLoggedIn = /* read auth provider */ false;
    if (!isLoggedIn && state.matchedLocation != '/login') return '/login';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
    ShellRoute(
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: '/discover',
          builder: (_, __) => const DiscoverScreen(),
        ),
        GoRoute(
          path: '/playground',
          builder: (_, state) {
            // Accept optional pre-filled outfit from Assistant handoff
            final extra = state.extra as Map<String, dynamic>?;
            return PlaygroundScreen(prefilledSlots: extra?['slots']);
          },
        ),
        GoRoute(
          path: '/assistant',
          builder: (_, __) => const AssistantScreen(),
        ),
        GoRoute(
          path: '/wardrobe',
          builder: (_, __) => const WardrobeScreen(),
          routes: [
            GoRoute(
              path: 'item/:id',
              builder: (_, state) =>
                  WardrobeItemDetailScreen(itemId: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    ),
  ],
);
```

### Main Scaffold with Bottom Nav (`lib/core/widgets/main_scaffold.dart`)

```dart
class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({required this.child, super.key});

  static const _tabs = ['/discover', '/playground', '/assistant', '/wardrobe'];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _tabs.indexWhere((t) => location.startsWith(t));

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex < 0 ? 0 : currentIndex,
        onDestinationSelected: (i) => context.go(_tabs[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.checkroom_outlined), label: 'Playground'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), label: 'Assistant'),
          NavigationDestination(icon: Icon(Icons.door_sliding_outlined), label: 'Wardrobe'),
        ],
      ),
    );
  }
}
```

### Assistant → Playground Handoff

```dart
// In AssistantScreen, when user taps "Try On":
context.go(
  '/playground',
  extra: {'slots': outfit.slots}, // Map<String, String> itemId per slot
);
```

---

## 4. State Management (Riverpod)

Use `flutter_riverpod` with `riverpod_annotation` for code-gen providers.

### Conventions

| Provider type | Use case |
|---------------|----------|
| `@riverpod` (auto-dispose) | Screen-scoped async data (catalog search, outfit suggestions) |
| `@Riverpod(keepAlive: true)` | App-lifetime state (auth, wardrobe cache) |
| `StateNotifierProvider` | Complex mutable state (outfit slot builder, assistant params) |
| `FutureProvider` | Simple one-shot async reads |

### Example: Wardrobe Provider

```dart
// features/wardrobe/providers/wardrobe_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'wardrobe_provider.g.dart';

@Riverpod(keepAlive: true)
class WardrobeNotifier extends _$WardrobeNotifier {
  @override
  Future<List<WardrobeItem>> build() => ref.read(wardrobeRepositoryProvider).fetchAll();

  Future<void> addItem(WardrobeItem item) async {
    await ref.read(wardrobeRepositoryProvider).save(item);
    ref.invalidateSelf(); // re-fetch
  }

  Future<void> deleteItem(String id) async {
    await ref.read(wardrobeRepositoryProvider).delete(id);
    ref.invalidateSelf();
  }
}
```

### Example: Outfit Slot Builder

```dart
// features/playground/providers/slot_builder_provider.dart
class OutfitSlots {
  final Map<SlotType, CatalogOrWardrobeItem?> slots;
  const OutfitSlots(this.slots);

  OutfitSlots copyWith(SlotType slot, CatalogOrWardrobeItem? item) =>
      OutfitSlots({...slots, slot: item});

  bool get isValid =>
      slots[SlotType.top] != null &&
      slots[SlotType.bottom] != null &&
      slots[SlotType.shoes] != null;
}

class SlotBuilderNotifier extends StateNotifier<OutfitSlots> {
  SlotBuilderNotifier() : super(OutfitSlots({
    SlotType.top: null,
    SlotType.bottom: null,
    SlotType.shoes: null,
    SlotType.accessory: null,
    SlotType.outerwear: null,
    SlotType.bag: null,
  }));

  void setSlot(SlotType type, CatalogOrWardrobeItem? item) =>
      state = state.copyWith(type, item);

  void prefill(Map<String, String> itemIds) {
    // Called on Assistant → Playground handoff
    // Resolve item IDs to full objects via catalog/wardrobe cache
  }

  void clear() => state = OutfitSlots({for (var t in SlotType.values) t: null});
}

final slotBuilderProvider =
    StateNotifierProvider.autoDispose<SlotBuilderNotifier, OutfitSlots>(
        (_) => SlotBuilderNotifier());
```

---

## 5. API Client & Data Layer

### Dio Setup (`lib/core/api/api_client.dart`)

```dart
import 'package:dio/dio.dart';

Dio createDio(String baseUrl, TokenStorage tokenStorage) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  // Auth interceptor
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await tokenStorage.read();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) {
      if (error.response?.statusCode == 401) {
        // Clear token and redirect to login
      }
      handler.next(error);
    },
  ));

  return dio;
}

final dioProvider = Provider<Dio>((ref) {
  final tokenStorage = ref.read(tokenStorageProvider);
  return createDio(dotenv.env['API_BASE_URL']!, tokenStorage);
});
```

### Endpoint Constants (`lib/core/api/api_endpoints.dart`)

```dart
class ApiEndpoints {
  // Auth
  static const signup = '/auth/signup';
  static const login = '/auth/login';

  // Catalog
  static const catalogSearch = '/catalog/search';
  static String catalogSimilar(String id) => '/catalog/similar/$id';

  // Wardrobe
  static const wardrobe = '/wardrobe';
  static const wardrobeTag = '/wardrobe/tag';
  static String wardrobeItem(String id) => '/wardrobe/$id';

  // Outfits
  static const outfitsSuggest = '/outfits/suggest';
  static const outfits = '/outfits';
  static String outfit(String id) => '/outfits/$id';

  // Try-On
  static const tryonSubmit = '/tryon/submit';
  static String tryonStatus(String jobId) => '/tryon/status/$jobId';
}
```

### Repository Pattern Example (Wardrobe)

```dart
// features/wardrobe/data/wardrobe_repository.dart
class WardrobeRepository {
  final Dio _dio;
  WardrobeRepository(this._dio);

  Future<List<WardrobeItem>> fetchAll({
    String? category,
    String sort = 'recent',
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.wardrobe,
      queryParameters: {
        if (category != null) 'category': category,
        'sort': sort,
        'limit': limit,
        'offset': offset,
      },
    );
    return (response.data['items'] as List)
        .map((e) => WardrobeItem.fromJson(e))
        .toList();
  }

  Future<WardrobeTagResult> tagPhoto(File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(imageFile.path, contentType: DioMediaType('image', 'jpeg')),
    });
    final response = await _dio.post(ApiEndpoints.wardrobeTag, data: formData);
    return WardrobeTagResult.fromJson(response.data);
  }

  Future<WardrobeItem> save(CreateWardrobeItemRequest body) async {
    final response = await _dio.post(ApiEndpoints.wardrobe, data: body.toJson());
    return WardrobeItem.fromJson(response.data);
  }

  Future<void> delete(String id) =>
      _dio.delete(ApiEndpoints.wardrobeItem(id));
}

final wardrobeRepositoryProvider = Provider(
    (ref) => WardrobeRepository(ref.read(dioProvider)));
```

---

## 6. Authentication Flow

### Token Storage (`lib/core/auth/token_storage.dart`)

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _key = 'auth_token';
  final _storage = const FlutterSecureStorage();

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String token) => _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}
```

### Auth Notifier (`lib/core/auth/auth_provider.dart`)

```dart
enum AuthStatus { loading, authenticated, unauthenticated }

class AuthNotifier extends StateNotifier<AuthStatus> {
  final Dio _dio;
  final TokenStorage _storage;

  AuthNotifier(this._dio, this._storage) : super(AuthStatus.loading) {
    _checkExistingToken();
  }

  Future<void> _checkExistingToken() async {
    final token = await _storage.read();
    state = token != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
  }

  Future<void> login(String email, String password) async {
    final response = await _dio.post(ApiEndpoints.login, data: {
      'email': email,
      'password': password,
    });
    await _storage.write(response.data['access_token']);
    state = AuthStatus.authenticated;
  }

  Future<void> signup(String email, String password) async {
    final response = await _dio.post(ApiEndpoints.signup, data: {
      'email': email,
      'password': password,
    });
    await _storage.write(response.data['access_token']);
    state = AuthStatus.authenticated;
  }

  Future<void> logout() async {
    await _storage.clear();
    state = AuthStatus.unauthenticated;
  }
}
```

### Login Screen (Minimal)

```dart
class LoginScreen extends ConsumerStatefulWidget { ... }

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref.read(authNotifierProvider.notifier)
          .login(_emailController.text, _passwordController.text);
      if (mounted) context.go('/discover');
    } catch (e) {
      setState(() { _error = 'Invalid email or password.'; });
    } finally {
      setState(() { _loading = false; });
    }
  }
}
```

---

## 7. Feature: Discover Tab

**MVP scope:** Static curated feed. No personalization in v1.0.

### Screen Structure

```
DiscoverScreen
├── ScrollView
│   ├── SectionHeader("Seasonal Edits")
│   ├── HorizontalOutfitRow(outfits: seasonalOutfits)
│   ├── SectionHeader("Occasion Collections")
│   └── HorizontalOutfitRow(outfits: occasionOutfits)
```

### Data

Discover content in v1.0 is **hardcoded or fetched from a static JSON endpoint**. No dynamic personalization. Display saved outfit cards from `GET /outfits` response for the "recently saved" row.

```dart
// Outfit card tapped → go to playground with pre-filled slots
context.go('/playground', extra: {'slots': outfit.slots});
```

---

## 8. Feature: Playground Tab

### Screen Structure

```
PlaygroundScreen
├── OutfitCanvas           ← slot grid (Top, Bottom, Shoes, Accessory, Outerwear, Bag)
├── GenerateButton         ← enabled when top+bottom+shoes filled
├── TryOnResultView        ← shown after generation completes
│   ├── GeneratedImage
│   └── ActionRow (Save, Share, Regenerate, Edit)
└── SlotBrowserSheet       ← opens on slot tap (bottom sheet)
    ├── CategoryTabs
    ├── ItemHorizontalScroll
    ├── FilterBar (color, brand, style, pattern, fit)
    └── FullScreenGrid (swipe-up expansion)
```

### Outfit Canvas

```dart
class OutfitCanvas extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slots = ref.watch(slotBuilderProvider).slots;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: SlotType.values.map((type) {
        final item = slots[type];
        return SlotTile(
          type: type,
          item: item,
          onTap: () => _openSlotBrowser(context, type),
        );
      }).toList(),
    );
  }

  void _openSlotBrowser(BuildContext context, SlotType type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ItemBrowserSheet(
        category: type.categoryString,
        onItemSelected: (item) {
          context.read(slotBuilderProvider.notifier).setSlot(type, item);
          Navigator.pop(context);
        },
      ),
    );
  }
}
```

### Slot Tile

```dart
class SlotTile extends StatelessWidget {
  final SlotType type;
  final CatalogOrWardrobeItem? item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: item == null
            ? _EmptySlot(type: type)
            : _FilledSlot(item: item!),
      ),
    );
  }
}
```

### Item Browser Sheet

```dart
class ItemBrowserSheet extends ConsumerStatefulWidget {
  final String category;
  final void Function(CatalogOrWardrobeItem) onItemSelected;
  // ...
}
```

The sheet fetches items from `GET /catalog/search?category={category}` and from the user's wardrobe, merged into a single list. Supports category tabs + filter chips.

**Swipe-up expansion:** Use `DraggableScrollableSheet` with `minChildSize: 0.5`, `maxChildSize: 1.0`.

### Generate Button & Try-On Flow

```dart
ElevatedButton(
  onPressed: slots.isValid && !isLoading ? () => _handleGenerate(ref) : null,
  child: isLoading
      ? const CircularProgressIndicator(color: Colors.white)
      : const Text('Generate Try-On'),
);

Future<void> _handleGenerate(WidgetRef ref) async {
  ref.read(tryonStateProvider.notifier).setLoading(true);
  try {
    final jobId = await ref.read(tryonRepositoryProvider).submit(slots);
    final imageUrl = await ref.read(tryonRepositoryProvider).poll(jobId);
    ref.read(tryonStateProvider.notifier).setResult(imageUrl);
  } catch (e) {
    _showError(context, e);
  } finally {
    ref.read(tryonStateProvider.notifier).setLoading(false);
  }
}
```

### Post-Generation Actions

| Button | Action |
|--------|--------|
| **Save to Lookbook** | `POST /outfits` with current slots + image URL |
| **Share** | `Share.shareXFiles([XFile(imageUrl)])` (use `share_plus` package) |
| **Regenerate** | Re-submit same slots to `/tryon/submit` |
| **Edit Outfit** | Close result view; slots remain filled for editing |

---

## 9. Feature: Assistant Tab

### Screen Flow

```
AssistantScreen
├── ParameterScreen        ← shown first
│   ├── OccasionPicker (8 options, horizontal chips)
│   ├── SeasonPicker (4 options)
│   ├── ColorPreferencePicker (5 options)
│   ├── SourcePicker (3 options: My Wardrobe / Shop / Mix)
│   └── FindOutfitsButton
└── OutfitSuggestionCarousel  ← shown after generation
    ├── PageView (3-5 cards, dot indicator)
    ├── RefreshButton
    └── OutfitCard
        ├── StackedItemImages
        ├── ItemNameList (tap → ItemDetailSheet)
        ├── StyleNote
        ├── TryOnButton  → go to /playground with pre-filled slots
        └── SaveOutfitButton
```

### Assistant Provider

```dart
class AssistantParams {
  final String? occasion;
  final String? season;
  final String? colorPreference;
  final String source; // 'wardrobe' | 'catalog' | 'mix'
  // ...
}

@riverpod
class AssistantNotifier extends _$AssistantNotifier {
  @override
  AsyncValue<List<OutfitSuggestion>> build() => const AsyncValue.data([]);

  Future<void> suggest(AssistantParams params) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() =>
        ref.read(outfitRepositoryProvider).suggest(params));
  }
}
```

### Outfit Suggestion Card

```dart
class OutfitSuggestionCard extends StatelessWidget {
  final OutfitSuggestion outfit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(children: [
        _StackedItemImages(slots: outfit.slots),
        _StyleNote(text: outfit.styleNote),
        Row(children: [
          TextButton(
            child: const Text('Try On'),
            onPressed: () => context.go('/playground', extra: {'slots': outfit.slotIds}),
          ),
          TextButton(
            child: const Text('Save'),
            onPressed: () => context.read(outfitRepositoryProvider).save(outfit),
          ),
        ]),
      ]),
    );
  }
}
```

### Item Detail Sheet (from card tap)

```dart
showModalBottomSheet(
  context: context,
  builder: (_) => ItemDetailSheet(item: item),
);

// ItemDetailSheet shows:
// - Full image
// - Name, brand, category
// - Buy link (launch_url)
```

---

## 10. Feature: Wardrobe Tab

### Screen Structure

```
WardrobeScreen
├── CategoryTabBar (All, Tops, Bottoms, Shoes, Outerwear, Accessories)
├── SortMenu (Color, Recently Added)
├── GridView.builder (≥50 items, lazy)
│   └── WardrobeItemCard → navigates to WardrobeItemDetailScreen
└── FAB (+) → _openAddItemFlow()
```

### Wardrobe Grid

```dart
GridView.builder(
  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    childAspectRatio: 0.75,
    crossAxisSpacing: 4,
    mainAxisSpacing: 4,
  ),
  itemCount: items.length,
  itemBuilder: (context, index) => WardrobeItemCard(item: items[index]),
)
```

**Performance:** Always use `GridView.builder` (lazy) + `CachedNetworkImage` with a fixed `200×200` thumbnail resolution. Wardrobe grid must maintain 60 fps on mid-range Android with 50+ items.

### Add Item Flow

```dart
Future<void> _openAddItemFlow(BuildContext context, WidgetRef ref) async {
  // 1. Pick image (camera or gallery)
  final picker = ImagePicker();
  final XFile? image = await picker.pickImage(
    source: ImageSource.camera,   // flat-lay or hanging
    imageQuality: 85,
    maxWidth: 1200,
  );
  if (image == null) return;

  // 2. Upload to R2 via pre-signed URL
  // 3. POST /wardrobe/tag → show TagConfirmationSheet
  // 4. User corrects any tags, taps "Save"
  // 5. POST /wardrobe to persist
  // 6. Invalidate wardrobe provider
}
```

### Tag Confirmation Sheet

```dart
class TagConfirmationSheet extends StatefulWidget {
  final WardrobeTagResult detectedTags;
  final String imageUrl;
  final void Function(EditedTags) onConfirm;
}
```

Show detected tags as editable chips/dropdowns. User must explicitly tap "Save to Wardrobe" before the item is persisted.

**Accepted tag fields with valid values:**

| Field | Valid values |
|-------|-------------|
| `category` | `top`, `bottom`, `shoes`, `accessory`, `outerwear`, `bag` |
| `pattern` | `solid`, `striped`, `floral`, `plaid`, `graphic`, `other` |
| `fit` | `fitted`, `relaxed`, `oversized`, `a-line`, `straight` |
| `color` | free text array |
| `style_tags` | free text array, 2–4 items |

### Wardrobe Item Detail Screen

```dart
class WardrobeItemDetailScreen extends ConsumerWidget {
  final String itemId;
  // ...

  // Shows:
  // - Full image
  // - All tags (inline editable)
  // - "Times used in outfits" count
  // - "Find matching items" button → go to /assistant with anchor item
  // - Delete button (soft-delete with confirmation dialog)
}
```

**"Find matching items" handoff:**

```dart
context.go('/assistant', extra: {'anchorItemId': item.id});
// AssistantScreen reads this extra and pre-locks the anchor item in params
```

---

## 11. Shared Components & Widgets

### `CachedItemImage`

Wrapper around `CachedNetworkImage` with consistent placeholder and error state.

```dart
class CachedItemImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => Container(color: Colors.grey.shade100),
      errorWidget: (_, __, ___) => const Icon(Icons.broken_image_outlined),
    );
  }
}
```

### `FilterChipRow`

Horizontal scrollable row of filter chips used in item browser and wardrobe screen.

```dart
class FilterChipRow extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final void Function(String, bool) onChanged;
  // ...
}
```

### `OutfitLookbookGrid`

Reusable grid used in the Lookbook section. Tap restores outfit to Playground.

```dart
class OutfitLookbookGrid extends StatelessWidget {
  final List<SavedOutfit> outfits;
  // Tapping an outfit: context.go('/playground', extra: {'slots': outfit.slots})
}
```

### `LoadingOverlay`

Full-screen semi-transparent overlay with spinner. Used during try-on generation.

```dart
class LoadingOverlay extends StatelessWidget {
  final bool isVisible;
  final String? message;
  final Widget child;
  // ...
}
```

---

## 12. Image Handling & Upload

### Upload Flow (Wardrobe Photo)

1. User picks image via `ImagePicker`
2. Flutter requests a pre-signed upload URL: `GET /wardrobe/upload-url?item_id={uuid}`
3. Flutter uploads the image directly to R2 using a `PUT` request with `Content-Type: image/jpeg`
4. Flutter calls `POST /wardrobe/tag` with `multipart/form-data` (the actual image bytes)
5. User confirms tags
6. Flutter calls `POST /wardrobe` with tags + the R2 image URL

```dart
Future<String> uploadToR2(String presignedUrl, File imageFile) async {
  final bytes = await imageFile.readAsBytes();
  final response = await Dio().put(
    presignedUrl,
    data: Stream.fromIterable([bytes]),
    options: Options(
      headers: {
        'Content-Type': 'image/jpeg',
        'Content-Length': bytes.length,
      },
    ),
  );
  if (response.statusCode != 200) throw Exception('Upload failed');
  // Derive the final CDN URL from the presigned URL path
  return _extractCdnUrl(presignedUrl);
}
```

### Image Compression

Always compress before upload to stay within the 10 MB limit and reduce upload time:

```dart
final XFile? image = await picker.pickImage(
  source: ImageSource.camera,
  imageQuality: 85,   // JPEG quality
  maxWidth: 1200,     // Max dimension
  maxHeight: 1200,
);
```

---

## 13. Try-On Polling Flow

### Polling Function

```dart
// features/playground/data/tryon_repository.dart

Future<String> pollTryonResult(String jobId) async {
  const maxAttempts = 15;
  const interval = Duration(seconds: 2);

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    await Future.delayed(interval);
    final response = await _dio.get(ApiEndpoints.tryonStatus(jobId));
    final status = response.data['status'] as String;

    switch (status) {
      case 'complete':
        return response.data['image_url'] as String;
      case 'failed':
        throw TryOnException(response.data['error'] ?? 'generation_failed');
      case 'pending':
      case 'processing':
        continue; // keep polling
    }
  }
  throw TryOnException('generation_timeout');
}
```

### Submit + Poll

```dart
Future<String> submitAndWait(Map<String, String> slots, {String? userPhotoUrl}) async {
  final submitResponse = await _dio.post(ApiEndpoints.tryonSubmit, data: {
    'slots': slots,
    'model_preference': 'neutral',
    'user_photo_url': userPhotoUrl,
  });

  final jobId = submitResponse.data['job_id'] as String;
  return pollTryonResult(jobId);
}
```

### Timeout & Error UX

| Error | Message shown to user |
|-------|-----------------------|
| `generation_timeout` | "Generation is taking longer than usual. Please try again." |
| `generation_failed` | "Something went wrong generating your outfit. Please try again." |
| Network error | "No connection. Check your internet and retry." |

---

## 14. Error Handling

### Global DioException Handler

```dart
String dioErrorToMessage(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
      return 'Request timed out. Please check your connection.';
    case DioExceptionType.badResponse:
      final statusCode = e.response?.statusCode;
      if (statusCode == 401) return 'Session expired. Please log in again.';
      if (statusCode == 422) return 'Invalid request. Please check your inputs.';
      if (statusCode != null && statusCode >= 500) return 'Server error. Please try again later.';
      return 'Unexpected error. Please try again.';
    case DioExceptionType.cancel:
      return 'Request was cancelled.';
    default:
      return 'No connection. Please check your internet.';
  }
}
```

### Snackbar Helper

```dart
void showErrorSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
```

### AsyncValue Error Handling in UI

```dart
ref.watch(wardrobeProvider).when(
  data: (items) => WardrobeGrid(items: items),
  loading: () => const CircularProgressIndicator(),
  error: (error, _) => ErrorView(
    message: dioErrorToMessage(error as DioException),
    onRetry: () => ref.invalidate(wardrobeProvider),
  ),
);
```

---

## 15. Performance Guidelines

### Wardrobe Grid (60 fps on mid-range Android)

- Use `GridView.builder` — never `GridView(children: [...])`
- Set fixed thumbnail size in `CachedNetworkImage` (`width: 200, height: 200`)
- The R2/S3 CDN should serve pre-resized 200×200 thumbnails (not full-res)
- Keep item card widgets as `const` where possible
- Do not perform layout work or JSON parsing in `build()`

### Image Caching

`CachedNetworkImage` caches to disk automatically. Set a reasonable max cache age:

```dart
CacheManager(
  Config('fashion_images', maxNrOfCacheObjects: 200, stalePeriod: const Duration(days: 7)),
)
```

### Pagination

All list endpoints support `limit` + `offset`. Implement infinite scroll for catalog browser and wardrobe grid. Load in batches of 30.

```dart
// In ScrollController listener:
if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 200) {
  ref.read(catalogProvider.notifier).loadMore();
}
```

### Try-On Loading UX

- Show a skeleton/shimmer loading state while polling, not just a spinner
- Animate the loading state (e.g., cycling through "Styling outfit...", "Rendering look...", "Almost ready...")
- Never block the main thread during the poll loop — `Future.delayed` is non-blocking

---

## 16. Environment Configuration

### `.env` (Flutter)

```bash
API_BASE_URL=https://api.yourbackend.com
```

### Loading `.env`

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const ProviderScope(child: FashionApp()));
}
```

### Accessing env vars

```dart
final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000';
```

**Never commit `.env` to source control.** Add to `.gitignore`.

---

## 17. Data Models (Dart)

All models use `freezed` + `json_serializable`. Run `build_runner` after any model change.

### `CatalogItem`

```dart
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
    required List<String> styleTags,
    required String imageUrl,
    String? productUrl,
  }) = _CatalogItem;

  factory CatalogItem.fromJson(Map<String, dynamic> json) =>
      _$CatalogItemFromJson(json);
}
```

### `WardrobeItem`

```dart
@freezed
class WardrobeItem with _$WardrobeItem {
  const factory WardrobeItem({
    required String id,
    required String userId,
    required String category,
    String? subtype,
    required List<String> color,
    String? pattern,
    String? fit,
    required List<String> styleTags,
    required String imageUrl,
    required int timesUsed,
    required DateTime createdAt,
  }) = _WardrobeItem;

  factory WardrobeItem.fromJson(Map<String, dynamic> json) =>
      _$WardrobeItemFromJson(json);
}
```

### `WardrobeTagResult`

```dart
@freezed
class WardrobeTagResult with _$WardrobeTagResult {
  const factory WardrobeTagResult({
    required String category,
    String? subtype,
    required List<String> color,
    String? pattern,
    String? fit,
    required List<String> styleTags,
    required double confidence,
  }) = _WardrobeTagResult;

  factory WardrobeTagResult.fromJson(Map<String, dynamic> json) =>
      _$WardrobeTagResultFromJson(json);
}
```

### `OutfitSuggestion`

```dart
@freezed
class OutfitSuggestion with _$OutfitSuggestion {
  const factory OutfitSuggestion({
    required Map<String, SlotItem> slots,  // "top", "bottom", "shoes", etc.
    required String styleNote,
  }) = _OutfitSuggestion;

  factory OutfitSuggestion.fromJson(Map<String, dynamic> json) =>
      _$OutfitSuggestionFromJson(json);

  // Convenience: extract just the item IDs for Playground handoff
}

@freezed
class SlotItem with _$SlotItem {
  const factory SlotItem({
    required String id,
    required String name,
    required String brand,
    required String imageUrl,
    String? productUrl,
  }) = _SlotItem;

  factory SlotItem.fromJson(Map<String, dynamic> json) =>
      _$SlotItemFromJson(json);
}
```

### `SavedOutfit`

```dart
@freezed
class SavedOutfit with _$SavedOutfit {
  const factory SavedOutfit({
    required String id,
    required String source,              // 'playground' | 'assistant'
    required Map<String, String> slots,  // slotType → itemId
    String? generatedImageUrl,
    required DateTime createdAt,
  }) = _SavedOutfit;

  factory SavedOutfit.fromJson(Map<String, dynamic> json) =>
      _$SavedOutfitFromJson(json);
}
```

### `SlotType` Enum

```dart
enum SlotType {
  top,
  bottom,
  shoes,
  accessory,
  outerwear,
  bag;

  String get categoryString => name; // matches backend category values
  String get displayName => switch (this) {
    SlotType.top => 'Top',
    SlotType.bottom => 'Bottom',
    SlotType.shoes => 'Shoes',
    SlotType.accessory => 'Accessory',
    SlotType.outerwear => 'Outerwear',
    SlotType.bag => 'Bag',
  };

  bool get isRequired => this == SlotType.top ||
      this == SlotType.bottom ||
      this == SlotType.shoes;
}
```

---

## 18. API Endpoint Reference (Flutter-Facing)

All requests require `Authorization: Bearer <token>` except `/auth/*`.

| Method | Endpoint | Flutter Usage |
|--------|----------|---------------|
| `POST` | `/auth/signup` | Registration screen |
| `POST` | `/auth/login` | Login screen |
| `GET` | `/catalog/search` | Item browser in Playground slot sheet |
| `GET` | `/catalog/similar/{id}` | "More like this" in item detail |
| `GET` | `/wardrobe` | Wardrobe tab grid |
| `POST` | `/wardrobe` | Save confirmed item after tagging |
| `DELETE` | `/wardrobe/{id}` | Delete item from Wardrobe detail screen |
| `POST` | `/wardrobe/tag` | Auto-tag photo before confirmation |
| `POST` | `/outfits/suggest` | Assistant "Find Outfits" CTA |
| `GET` | `/outfits` | Lookbook grid |
| `POST` | `/outfits` | Save outfit from Playground or Assistant |
| `DELETE` | `/outfits/{id}` | Remove from Lookbook |
| `POST` | `/tryon/submit` | Playground "Generate" button |
| `GET` | `/tryon/status/{job_id}` | Polling loop (every 2s, max 30s) |

### Key Request/Response Shapes

**POST `/outfits/suggest`**

```json
// Request
{ "occasion": "brunch", "season": "spring", "color_preference": "neutral", "source": "mix" }

// Response
{
  "outfits": [{
    "slots": {
      "top": { "id": "uuid", "name": "Linen Shirt", "brand": "mango", "image_url": "..." },
      "bottom": { "id": "uuid", ... },
      "shoes": { "id": "uuid", ... }
    },
    "style_note": "A relaxed spring look ideal for a sunny brunch."
  }]
}
```

**POST `/tryon/submit`**

```json
// Request
{ "slots": { "top": "uuid", "bottom": "uuid", "shoes": "uuid" }, "model_preference": "neutral", "user_photo_url": null }

// Response
{ "job_id": "kling-job-uuid", "status": "pending" }
```

**GET `/tryon/status/{job_id}`**

```json
// Complete
{ "job_id": "...", "status": "complete", "image_url": "https://cdn.example.com/tryon/result.jpg" }

// Still processing
{ "job_id": "...", "status": "processing" }

// Failed
{ "job_id": "...", "status": "failed", "error": "generation_timeout" }
```

---

*End of Flutter Technical Documentation*
