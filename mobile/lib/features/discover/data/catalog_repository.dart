import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/api/api_client.dart';
import 'package:fashion_app/core/api/api_endpoints.dart';
import 'package:fashion_app/core/models/catalog_item.dart';

class CatalogRepository {
  final Dio _dio;
  CatalogRepository(this._dio);

  Future<List<CatalogItem>> search({
    String? category,
    String? color,
    String? brand,
    String? style,
    String? fit,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.catalogSearch,
      queryParameters: {
        if (category != null) 'category': category,
        if (color != null) 'color': color,
        if (brand != null) 'brand': brand,
        if (style != null) 'style': style,
        if (fit != null) 'fit': fit,
        'limit': limit,
        'offset': offset,
      },
    );
    return (response.data['items'] as List)
        .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CatalogItem>> similar(
    String itemId, {
    int limit = 10,
    String source = 'catalog',
  }) async {
    final response = await _dio.get(
      ApiEndpoints.catalogSimilar(itemId),
      queryParameters: {'limit': limit, 'source': source},
    );
    return (response.data['items'] as List)
        .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>(
    (ref) => CatalogRepository(ref.read(dioProvider)));
