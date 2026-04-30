import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/playground_models.dart';
import 'package:fashion_app/features/playground/data/playground_repository.dart';

/// Combined snapshot of the library data the playground UI needs upfront.
class PlaygroundLibrary {
  final PlaygroundSystemPrompt systemPrompt;
  final List<PlaygroundTemplate> templates;
  final List<PlaygroundPersona> allPersonas;
  const PlaygroundLibrary({
    required this.systemPrompt,
    required this.templates,
    required this.allPersonas,
  });

  List<PlaygroundPersona> personasFor(String gender) =>
      allPersonas.where((p) => p.gender == gender).toList(growable: false);
}

/// Fetches the active system prompt, all active templates, and all active
/// personas (across genders) in parallel. Cached for the app's lifetime;
/// callers can invalidate via `ref.invalidate(playgroundLibraryProvider)`
/// when an admin edits something on the web side and the user wants fresh
/// data on mobile.
final playgroundLibraryProvider =
    FutureProvider<PlaygroundLibrary>((ref) async {
  final repo = ref.read(playgroundRepositoryProvider);
  final results = await Future.wait([
    repo.getActiveSystemPrompt(),
    repo.listTemplates(),
    repo.listPersonas(),
  ]);
  return PlaygroundLibrary(
    systemPrompt: results[0] as PlaygroundSystemPrompt,
    templates: results[1] as List<PlaygroundTemplate>,
    allPersonas: results[2] as List<PlaygroundPersona>,
  );
});
