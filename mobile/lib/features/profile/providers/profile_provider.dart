import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/outfit_models.dart';
import 'package:fashion_app/features/assistant/data/outfit_repository.dart';
import 'package:fashion_app/features/profile/data/profile_repository.dart';

class ProfileState {
  final ProfileUser user;
  final List<SavedOutfit> savedOutfits;
  final Set<String> likedOutfitIds;
  final List<String> recentlyViewedOutfitIds;
  final StylePreferences stylePreferences;
  final ProfileSettings settings;

  const ProfileState({
    required this.user,
    required this.savedOutfits,
    required this.likedOutfitIds,
    required this.recentlyViewedOutfitIds,
    required this.stylePreferences,
    required this.settings,
  });

  List<SavedOutfit> get likedOutfits =>
      savedOutfits.where((outfit) => likedOutfitIds.contains(outfit.id)).toList();

  List<SavedOutfit> get recentlyViewedOutfits {
    final byId = {for (final outfit in savedOutfits) outfit.id: outfit};
    return recentlyViewedOutfitIds
        .map((id) => byId[id])
        .whereType<SavedOutfit>()
        .toList();
  }

  ProfileState copyWith({
    ProfileUser? user,
    List<SavedOutfit>? savedOutfits,
    Set<String>? likedOutfitIds,
    List<String>? recentlyViewedOutfitIds,
    StylePreferences? stylePreferences,
    ProfileSettings? settings,
  }) {
    return ProfileState(
      user: user ?? this.user,
      savedOutfits: savedOutfits ?? this.savedOutfits,
      likedOutfitIds: likedOutfitIds ?? this.likedOutfitIds,
      recentlyViewedOutfitIds:
          recentlyViewedOutfitIds ?? this.recentlyViewedOutfitIds,
      stylePreferences: stylePreferences ?? this.stylePreferences,
      settings: settings ?? this.settings,
    );
  }
}

class ProfileNotifier extends StateNotifier<AsyncValue<ProfileState>> {
  final ProfileRepository _profileRepository;
  final OutfitRepository _outfitRepository;

  ProfileNotifier(this._profileRepository, this._outfitRepository)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final remoteUser = await _profileRepository.fetchUser();
      final localData = await _profileRepository.loadLocalData(remoteUser.id);
      final savedOutfits = await _outfitRepository.listSaved();

      return ProfileState(
        user: ProfileUser(
          id: remoteUser.id,
          email: remoteUser.email,
          username: localData.username ?? _defaultUsername(remoteUser.email),
          bio: localData.bio,
          photoUrl: localData.photoUrl,
          skinTone: remoteUser.skinTone,
          createdAt: remoteUser.createdAt,
        ),
        savedOutfits: savedOutfits,
        likedOutfitIds: localData.likedOutfitIds,
        recentlyViewedOutfitIds: localData.recentlyViewedOutfitIds,
        stylePreferences: localData.stylePreferences,
        settings: localData.settings,
      );
    });
  }

  Future<void> updateProfile({
    required String username,
    required String bio,
    String? photoUrl,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;

    await _profileRepository.saveProfile(
      userId: current.user.id,
      username: username,
      bio: bio,
      photoUrl: photoUrl,
    );
    state = AsyncValue.data(
      current.copyWith(
        user: current.user.copyWith(
          username: username.trim(),
          bio: bio.trim(),
          photoUrl: photoUrl?.trim().isEmpty ?? true ? null : photoUrl!.trim(),
        ),
      ),
    );
  }

  Future<void> toggleLikedOutfit(String outfitId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final likedIds = {...current.likedOutfitIds};
    if (!likedIds.add(outfitId)) {
      likedIds.remove(outfitId);
    }
    await _profileRepository.saveLikedOutfitIds(current.user.id, likedIds);
    state = AsyncValue.data(current.copyWith(likedOutfitIds: likedIds));
  }

  Future<void> markRecentlyViewed(String outfitId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final viewedIds = [
      outfitId,
      ...current.recentlyViewedOutfitIds.where((id) => id != outfitId),
    ].take(12).toList();

    await _profileRepository.saveRecentlyViewedOutfitIds(
      current.user.id,
      viewedIds,
    );
    state = AsyncValue.data(
      current.copyWith(recentlyViewedOutfitIds: viewedIds),
    );
  }

  Future<void> updateStylePreferences(StylePreferences preferences) async {
    final current = state.valueOrNull;
    if (current == null) return;

    await _profileRepository.saveStylePreferences(current.user.id, preferences);
    state = AsyncValue.data(
      current.copyWith(stylePreferences: preferences),
    );
  }

  Future<void> updateSettings(ProfileSettings settings) async {
    final current = state.valueOrNull;
    if (current == null) return;

    await _profileRepository.saveSettings(current.user.id, settings);
    state = AsyncValue.data(current.copyWith(settings: settings));
  }

  static String _defaultUsername(String email) {
    final prefix = email.split('@').first.trim();
    if (prefix.isEmpty) return 'Outfitter';
    return prefix
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }
}

final profileNotifierProvider =
    StateNotifierProvider.autoDispose<ProfileNotifier, AsyncValue<ProfileState>>(
  (ref) => ProfileNotifier(
    ref.read(profileRepositoryProvider),
    ref.read(outfitRepositoryProvider),
  ),
);
