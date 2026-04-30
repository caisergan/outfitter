import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/api/api_client.dart';
import 'package:fashion_app/core/api/api_endpoints.dart';
import 'package:fashion_app/core/models/outfit_models.dart';
import '/features/assistant/ui/mock_data.dart';

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
        .map((e) => SavedOutfit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SavedOutfit> save({
    required String source,
    required Map<String, String> slots,
    String? generatedImageUrl,
  }) async {
    final response = await _dio.post(ApiEndpoints.outfits, data: {
      'source': source,
      'slots': slots,
      if (generatedImageUrl != null) 'generated_image_url': generatedImageUrl,
    });
    return SavedOutfit.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete(ApiEndpoints.outfit(id));
  }
}

final outfitRepositoryProvider = Provider<OutfitRepository>(
    (ref) => OutfitRepository(ref.read(dioProvider)));
