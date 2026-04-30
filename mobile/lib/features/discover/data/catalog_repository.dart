import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/api/api_client.dart';
import 'package:fashion_app/core/api/api_endpoints.dart';
import 'package:fashion_app/core/models/catalog_filter_options.dart';
import 'package:fashion_app/core/models/catalog_item.dart';

class CatalogRepository {
  final Dio _dio;
  CatalogRepository(this._dio);

  static const int _catalogPageSize = 100;

  CatalogItem _catalogItemFromApi(Map<String, dynamic> json) {
    final imageFrontUrl = json['image_front_url'];
    return CatalogItem.fromJson({
      ...json,
      if (imageFrontUrl is String && imageFrontUrl.isNotEmpty)
        'image_url': imageFrontUrl,
    });
  }

  Future<({List<CatalogItem> items, int total})> searchPage({
    String? category,
    String? subtype,
    String? color,
    String? brand,
    String? gender,
    String? style,
    String? fit,
    String? query,
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
        if (gender != null) 'gender': gender,
        if (style != null) 'style': style,
        if (fit != null) 'fit': fit,
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        'limit': limit,
        'offset': offset,
      },
    );

    final data = response.data as Map<String, dynamic>;
    return (
      items: (data['items'] as List)
          .map((e) => _catalogItemFromApi(e as Map<String, dynamic>))
          .toList(),
      total: data['total'] as int? ?? 0,
    );
  }

  Future<CatalogFilterOptions> fetchFilterOptions() async {
    final response = await _dio.get(ApiEndpoints.catalogFilterOptions);
    final data = response.data as Map<String, dynamic>;
    return CatalogFilterOptions.fromJson(data);
  }

  Future<List<CatalogItem>> search({
    String? category,
    String? subtype,
    String? color,
    String? brand,
    String? gender,
    String? style,
    String? fit,
    String? query,
    int limit = 20,
    int offset = 0,
  }) async {
    final page = await searchPage(
      category: category,
      subtype: subtype,
      color: color,
      brand: brand,
      gender: gender,
      style: style,
      fit: fit,
      query: query,
      limit: limit,
      offset: offset,
    );
    return page.items;
  }

  int get catalogPageSize => _catalogPageSize;

  Future<List<CatalogItem>> searchAll({
    String? category,
    String? color,
    String? brand,
    String? style,
    String? fit,
  }) async {
    final firstPage = await searchPage(
      category: category,
      color: color,
      brand: brand,
      style: style,
      fit: fit,
      limit: _catalogPageSize,
      offset: 0,
    );

    final items = <CatalogItem>[...firstPage.items];
    final total = firstPage.total;

    if (items.isEmpty || items.length >= total) {
      return items;
    }

    final remainingOffsets = <int>[];
    for (var offset = items.length; offset < total; offset += _catalogPageSize) {
      remainingOffsets.add(offset);
    }

    final remainingPages = await Future.wait(
      remainingOffsets.map(
        (offset) => searchPage(
          category: category,
          color: color,
          brand: brand,
          style: style,
          fit: fit,
          limit: _catalogPageSize,
          offset: offset,
        ),
      ),
    );

    for (final page in remainingPages) {
      if (page.items.isEmpty) {
        break;
      }
      items.addAll(page.items);
    }

    return items;
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
        .map((e) => _catalogItemFromApi(e as Map<String, dynamic>))
        .toList();
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>(
    (ref) => CatalogRepository(ref.read(dioProvider)));
