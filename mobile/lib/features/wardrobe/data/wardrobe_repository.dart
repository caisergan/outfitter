import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/api/api_client.dart';
import 'package:fashion_app/core/api/api_endpoints.dart';
import 'package:fashion_app/core/models/wardrobe_item.dart';

class WardrobeRepository {
  final Dio _dio;
  WardrobeRepository(this._dio);

  Future<List<WardrobeItem>> fetchAll({
    String? slot,
    String? category,
    String sort = 'recent',
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.wardrobe,
      queryParameters: {
        if (slot != null) 'slot': slot,
        if (category != null) 'category': category,
        'sort': sort,
        'limit': limit,
        'offset': offset,
      },
    );
    return (response.data['items'] as List)
        .map((e) => WardrobeItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<WardrobeTagResult> tagPhoto(String imagePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        imagePath,
        contentType: DioMediaType('image', 'jpeg'),
      ),
    });
    final response = await _dio.post(ApiEndpoints.wardrobeTag, data: formData);
    return WardrobeTagResult.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WardrobeItem> save(CreateWardrobeItemRequest body) async {
    final response = await _dio.post(
      ApiEndpoints.wardrobe,
      data: body.toJson(),
    );
    return WardrobeItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) async {
    await _dio.delete(ApiEndpoints.wardrobeItem(id));
  }
}

final wardrobeRepositoryProvider = Provider<WardrobeRepository>(
    (ref) => WardrobeRepository(ref.read(dioProvider)));
