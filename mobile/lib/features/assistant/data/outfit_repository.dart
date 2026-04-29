import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/api/api_client.dart';
import 'package:fashion_app/core/api/api_endpoints.dart';
import 'package:fashion_app/core/models/outfit_models.dart';
import '/features/assistant/ui/mew.dart';

class OutfitRepository {
  final Dio _dio;
  OutfitRepository(this._dio);

  Future<List<OutfitSuggestion>> suggest(AssistantParams params) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.outfitsSuggest,
        data: params.toJson(),
      );

      final data = response.data;

      if (data == null || data['outfits'] == null) {
        return buildMockOutfits();
      }

      return (data['outfits'] as List)
          .map((e) => OutfitSuggestion.fromJson(e))
          .toList();
    } catch (e) {
      // fallback when API fails
      return buildMockOutfits();
    }
  }

  Future<List<SavedOutfit>> listSaved() async {
    final response = await _dio.get(ApiEndpoints.outfits);
    final data = response.data as Map<String, dynamic>;
    final items = (data['items'] ?? data['outfits']) as List;
    return items
        .map(
          (e) => SavedOutfit.fromJson(
            _normalizeSavedOutfitJson(e as Map<String, dynamic>),
          ),
        )
        .toList();
  }

  Future<SavedOutfit> save({
    required String source,
    required Map<String, dynamic> slots,
    String? generatedImageUrl,
  }) async {
    final response = await _dio.post(ApiEndpoints.outfits, data: {
      'source': source,
      'slots': slots,
      if (generatedImageUrl != null) 'generated_image_url': generatedImageUrl,
    });
    return SavedOutfit.fromJson(
      _normalizeSavedOutfitJson(response.data as Map<String, dynamic>),
    );
  }

  Future<void> delete(String id) async {
    await _dio.delete(ApiEndpoints.outfit(id));
  }

  Map<String, dynamic> _normalizeSavedOutfitJson(Map<String, dynamic> json) {
    final rawSlots = json['slots'];
    if (rawSlots is! Map) return json;

    final normalizedSlots = <String, String>{};
    for (final entry in rawSlots.entries) {
      final key = entry.key.toString();
      final value = entry.value;

      if (value is Map<String, dynamic>) {
        final imageUrl = value['image_url'] ?? value['imageUrl'];
        final id = value['id'];
        if (imageUrl != null) {
          normalizedSlots[key] = imageUrl.toString();
        } else if (id != null) {
          normalizedSlots[key] = id.toString();
        }
      } else if (value is Map) {
        final imageUrl = value['image_url'] ?? value['imageUrl'];
        final id = value['id'];
        if (imageUrl != null) {
          normalizedSlots[key] = imageUrl.toString();
        } else if (id != null) {
          normalizedSlots[key] = id.toString();
        }
      } else if (value != null) {
        normalizedSlots[key] = value.toString();
      }
    }

    return {
      ...json,
      'slots': normalizedSlots,
    };
  }
}

final outfitRepositoryProvider = Provider<OutfitRepository>(
    (ref) => OutfitRepository(ref.read(dioProvider)));
