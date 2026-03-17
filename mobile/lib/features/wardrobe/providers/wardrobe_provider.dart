import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/wardrobe_item.dart';
import 'package:fashion_app/features/wardrobe/data/wardrobe_repository.dart';

class WardrobeNotifier
    extends StateNotifier<AsyncValue<List<WardrobeItem>>> {
  final WardrobeRepository _repo;

  WardrobeNotifier(this._repo) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch({String? category, String sort = 'recent'}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
        () => _repo.fetchAll(category: category, sort: sort));
  }

  Future<void> addItem(CreateWardrobeItemRequest body) async {
    await _repo.save(body);
    await fetch();
  }

  Future<void> deleteItem(String id) async {
    await _repo.delete(id);
    await fetch();
  }
}

final wardrobeNotifierProvider =
    StateNotifierProvider<WardrobeNotifier, AsyncValue<List<WardrobeItem>>>(
        (ref) => WardrobeNotifier(ref.read(wardrobeRepositoryProvider)));
