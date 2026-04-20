import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fashion_app/core/api/api_client.dart';
import 'package:fashion_app/core/api/api_endpoints.dart';

class RemoteProfileUser {
  final String id;
  final String email;
  final String? skinTone;
  final DateTime createdAt;

  const RemoteProfileUser({
    required this.id,
    required this.email,
    required this.createdAt,
    this.skinTone,
  });

  factory RemoteProfileUser.fromJson(Map<String, dynamic> json) {
    return RemoteProfileUser(
      id: json['id'] as String,
      email: json['email'] as String,
      skinTone: json['skin_tone'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

class ProfileUser {
  final String id;
  final String email;
  final String username;
  final String bio;
  final String? photoUrl;
  final String? skinTone;
  final DateTime createdAt;

  const ProfileUser({
    required this.id,
    required this.email,
    required this.username,
    required this.bio,
    required this.createdAt,
    this.photoUrl,
    this.skinTone,
  });

  String get displayName => username.trim().isEmpty ? _emailName : username;

  String get initials {
    final name = displayName.trim();
    if (name.isEmpty) return 'O';
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final chars = parts.take(2).map((p) => p[0].toUpperCase()).join();
    return chars.isEmpty ? 'O' : chars;
  }

  String get _emailName => email.split('@').first;

  ProfileUser copyWith({
    String? username,
    String? bio,
    String? photoUrl,
  }) {
    return ProfileUser(
      id: id,
      email: email,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      photoUrl: photoUrl,
      skinTone: skinTone,
      createdAt: createdAt,
    );
  }
}

class StylePreferences {
  final Set<String> occasions;
  final Set<String> seasons;
  final Set<String> colorPalettes;
  final String sourcePreference;

  const StylePreferences({
    this.occasions = const {},
    this.seasons = const {},
    this.colorPalettes = const {},
    this.sourcePreference = 'mix',
  });

  bool get isEmpty =>
      occasions.isEmpty &&
      seasons.isEmpty &&
      colorPalettes.isEmpty &&
      sourcePreference == 'mix';

  StylePreferences copyWith({
    Set<String>? occasions,
    Set<String>? seasons,
    Set<String>? colorPalettes,
    String? sourcePreference,
  }) {
    return StylePreferences(
      occasions: occasions ?? this.occasions,
      seasons: seasons ?? this.seasons,
      colorPalettes: colorPalettes ?? this.colorPalettes,
      sourcePreference: sourcePreference ?? this.sourcePreference,
    );
  }
}

class ProfileSettings {
  final bool outfitReminders;
  final bool styleDropAlerts;
  final bool privateProfile;
  final bool personalizedRecommendations;

  const ProfileSettings({
    this.outfitReminders = true,
    this.styleDropAlerts = true,
    this.privateProfile = false,
    this.personalizedRecommendations = true,
  });

  ProfileSettings copyWith({
    bool? outfitReminders,
    bool? styleDropAlerts,
    bool? privateProfile,
    bool? personalizedRecommendations,
  }) {
    return ProfileSettings(
      outfitReminders: outfitReminders ?? this.outfitReminders,
      styleDropAlerts: styleDropAlerts ?? this.styleDropAlerts,
      privateProfile: privateProfile ?? this.privateProfile,
      personalizedRecommendations:
          personalizedRecommendations ?? this.personalizedRecommendations,
    );
  }
}

class LocalProfileData {
  final String? username;
  final String bio;
  final String? photoUrl;
  final Set<String> likedOutfitIds;
  final List<String> recentlyViewedOutfitIds;
  final StylePreferences stylePreferences;
  final ProfileSettings settings;

  const LocalProfileData({
    required this.bio,
    required this.likedOutfitIds,
    required this.recentlyViewedOutfitIds,
    required this.stylePreferences,
    required this.settings,
    this.username,
    this.photoUrl,
  });
}

class ProfileRepository {
  final Dio _dio;

  ProfileRepository(this._dio);

  Future<RemoteProfileUser> fetchUser() async {
    final response = await _dio.get(ApiEndpoints.authMe);
    return RemoteProfileUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<LocalProfileData> loadLocalData(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return LocalProfileData(
      username: prefs.getString(_key(userId, 'username')),
      bio: prefs.getString(_key(userId, 'bio')) ?? '',
      photoUrl: prefs.getString(_key(userId, 'photo_url')),
      likedOutfitIds:
          (prefs.getStringList(_key(userId, 'liked_outfit_ids')) ?? []).toSet(),
      recentlyViewedOutfitIds:
          prefs.getStringList(_key(userId, 'recently_viewed_outfit_ids')) ??
              const [],
      stylePreferences: StylePreferences(
        occasions: (prefs.getStringList(_key(userId, 'style_occasions')) ?? [])
            .toSet(),
        seasons:
            (prefs.getStringList(_key(userId, 'style_seasons')) ?? []).toSet(),
        colorPalettes:
            (prefs.getStringList(_key(userId, 'style_color_palettes')) ?? [])
                .toSet(),
        sourcePreference:
            prefs.getString(_key(userId, 'style_source_preference')) ?? 'mix',
      ),
      settings: ProfileSettings(
        outfitReminders:
            prefs.getBool(_key(userId, 'setting_outfit_reminders')) ?? true,
        styleDropAlerts:
            prefs.getBool(_key(userId, 'setting_style_drop_alerts')) ?? true,
        privateProfile:
            prefs.getBool(_key(userId, 'setting_private_profile')) ?? false,
        personalizedRecommendations:
            prefs.getBool(_key(userId, 'setting_personalized_recs')) ?? true,
      ),
    );
  }

  Future<void> saveProfile({
    required String userId,
    required String username,
    required String bio,
    String? photoUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId, 'username'), username.trim());
    await prefs.setString(_key(userId, 'bio'), bio.trim());
    final normalizedPhotoUrl = photoUrl?.trim() ?? '';
    if (normalizedPhotoUrl.isEmpty) {
      await prefs.remove(_key(userId, 'photo_url'));
    } else {
      await prefs.setString(_key(userId, 'photo_url'), normalizedPhotoUrl);
    }
  }

  Future<void> saveLikedOutfitIds(
      String userId, Set<String> likedOutfitIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key(userId, 'liked_outfit_ids'),
      likedOutfitIds.toList(),
    );
  }

  Future<void> saveRecentlyViewedOutfitIds(
    String userId,
    List<String> outfitIds,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key(userId, 'recently_viewed_outfit_ids'),
      outfitIds.take(12).toList(),
    );
  }

  Future<void> saveStylePreferences(
    String userId,
    StylePreferences preferences,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key(userId, 'style_occasions'),
      preferences.occasions.toList(),
    );
    await prefs.setStringList(
      _key(userId, 'style_seasons'),
      preferences.seasons.toList(),
    );
    await prefs.setStringList(
      _key(userId, 'style_color_palettes'),
      preferences.colorPalettes.toList(),
    );
    await prefs.setString(
      _key(userId, 'style_source_preference'),
      preferences.sourcePreference,
    );
  }

  Future<void> saveSettings(String userId, ProfileSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _key(userId, 'setting_outfit_reminders'),
      settings.outfitReminders,
    );
    await prefs.setBool(
      _key(userId, 'setting_style_drop_alerts'),
      settings.styleDropAlerts,
    );
    await prefs.setBool(
      _key(userId, 'setting_private_profile'),
      settings.privateProfile,
    );
    await prefs.setBool(
      _key(userId, 'setting_personalized_recs'),
      settings.personalizedRecommendations,
    );
  }

  String _key(String userId, String name) => 'profile.$userId.$name';
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.read(dioProvider)),
);
