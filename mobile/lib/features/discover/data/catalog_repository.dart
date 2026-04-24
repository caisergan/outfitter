import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/api/api_client.dart';
import 'package:fashion_app/core/api/api_endpoints.dart';
import 'package:fashion_app/core/models/catalog_item.dart';
import 'package:fashion_app/features/discover/models/catalog_filter_options.dart';

class CatalogRepository {
  final Dio _dio;
  CatalogRepository(this._dio);

  Future<List<CatalogItem>> search({
    String? category,
    String? subtype,
    String? color,
    String? brand,
    String? style,
    String? pattern,
    String? fit,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.catalogSearch,
      queryParameters: {
        if (category != null) 'category': category,
        if (subtype != null) 'subtype': subtype,
        if (color != null) 'color': color,
        if (brand != null) 'brand': brand,
        if (style != null) 'style': style,
        if (pattern != null) 'pattern': pattern,
        if (fit != null) 'fit': fit,
        'limit': limit,
        'offset': offset,
      },
    );
    return (response.data['items'] as List)
        .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CatalogFilterOptions> getFilterOptions({String? category}) async {
    final response = await _dio.get(
      ApiEndpoints.catalogFilterOptions,
      queryParameters: {
        if (category != null) 'category': category,
      },
    );
    return CatalogFilterOptions.fromJson(
      response.data as Map<String, dynamic>,
    );
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
