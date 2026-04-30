import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/tryon_models.dart';
import 'package:fashion_app/features/tryon/data/tryon_repository.dart';

class TryOnRunsState {
  final List<TryOnRun> items;
  final String? nextCursor;
  final bool loading;
  final Object? error;

  const TryOnRunsState({
    this.items = const [],
    this.nextCursor,
    this.loading = false,
    this.error,
  });

  TryOnRunsState copyWith({
    List<TryOnRun>? items,
    String? nextCursor,
    bool clearCursor = false,
    bool? loading,
    Object? error,
    bool clearError = false,
  }) {
    return TryOnRunsState(
      items: items ?? this.items,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TryOnRunsNotifier extends Notifier<TryOnRunsState> {
  static const int _pageSize = 10;

  @override
  TryOnRunsState build() {
    // Kick off the first fetch on the next microtask so we don't touch
    // `state` before build() has returned (which would otherwise blow up
    // with a "Tried to read the state of an uninitialized provider" error
    // on cold start).
    Future.microtask(refresh);
    return const TryOnRunsState(loading: true);
  }

  Future<void> refresh() async {
    final repo = ref.read(tryOnGenerationRepositoryProvider);
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await repo.listRuns(limit: _pageSize);
      state = TryOnRunsState(
        items: page.items,
        nextCursor: page.nextCursor,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (cursor == null || state.loading) return;
    final repo = ref.read(tryOnGenerationRepositoryProvider);
    state = state.copyWith(loading: true);
    try {
      final page = await repo.listRuns(limit: _pageSize, cursor: cursor);
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: page.nextCursor,
        clearCursor: page.nextCursor == null,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  /// Fetches a fresh first page from the server. Used after a successful (or
  /// failed) generation so the new row appears at the top without manual
  /// refresh.
  Future<void> refreshAfterGenerate() async => refresh();
}

final tryonRunsProvider = NotifierProvider<TryOnRunsNotifier, TryOnRunsState>(
  TryOnRunsNotifier.new,
);
