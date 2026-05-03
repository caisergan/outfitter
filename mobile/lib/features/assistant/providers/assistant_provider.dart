import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/outfit_models.dart';
import 'package:fashion_app/features/assistant/data/outfit_repository.dart';

class AssistantNotifier
    extends StateNotifier<AsyncValue<List<OutfitSuggestion>>> {
  final OutfitRepository _repo;
  AssistantParams? _lastParams;

  AssistantNotifier(this._repo) : super(const AsyncValue.data([]));

  Future<List<OutfitSuggestion>> suggest(AssistantParams params) async {
    _lastParams = params;

    state = const AsyncValue.loading();

    final result = await AsyncValue.guard(
      () => _repo.suggest(params),
    );

    // ✅ FIX: prevent crash after dispose
    if (!mounted) return result.valueOrNull ?? const [];

    state = result;
    return result.valueOrNull ?? const [];
  }

  Future<void> refresh() async {
    if (_lastParams != null) {
      await suggest(_lastParams!);
    }
  }
}

final assistantNotifierProvider = StateNotifierProvider<AssistantNotifier,
    AsyncValue<List<OutfitSuggestion>>>(
  (ref) => AssistantNotifier(ref.read(outfitRepositoryProvider)),
);

final savedOutfitsProvider =
    FutureProvider.autoDispose<List<SavedOutfit>>((ref) {
  return ref.read(outfitRepositoryProvider).listSaved();
});
