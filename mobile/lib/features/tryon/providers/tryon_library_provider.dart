import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fashion_app/core/models/tryon_models.dart';
import 'package:fashion_app/features/tryon/data/tryon_repository.dart';

/// Combined snapshot of the library data the tryon UI needs upfront.
class TryOnLibrary {
  final TryOnSystemPrompt systemPrompt;
  final List<TryOnTemplate> templates;
  final List<TryOnPersona> allPersonas;
  const TryOnLibrary({
    required this.systemPrompt,
    required this.templates,
    required this.allPersonas,
  });

  List<TryOnPersona> personasFor(String gender) =>
      allPersonas.where((p) => p.gender == gender).toList(growable: false);
}

/// Fetches the active system prompt, all active templates, and all active
/// personas (across genders) in parallel. Cached for the app's lifetime;
/// callers can invalidate via `ref.invalidate(tryonLibraryProvider)`
/// when an admin edits something on the web side and the user wants fresh
/// data on mobile.
final tryonLibraryProvider = FutureProvider<TryOnLibrary>((ref) async {
  final repo = ref.read(tryOnGenerationRepositoryProvider);
  final results = await Future.wait([
    repo.getActiveSystemPrompt(),
    repo.listTemplates(),
    repo.listPersonas(),
  ]);
  return TryOnLibrary(
    systemPrompt: results[0] as TryOnSystemPrompt,
    templates: results[1] as List<TryOnTemplate>,
    allPersonas: results[2] as List<TryOnPersona>,
  );
});
